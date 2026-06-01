import CasprFlowCore
import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Check failed: \(message)\n", stderr)
        exit(1)
    }
}

// Hotkey contract: Option + Space (push-to-talk).
expect(HotkeyDescriptor.defaultHotkey.displayName == "Option + Space", "default hotkey label")
expect(HotkeyDescriptor.defaultHotkey.keyCode == 49, "default hotkey key code (space)")
expect(HotkeyDescriptor.defaultHotkey.carbonModifiers == 2048, "default hotkey modifiers (option)")

// Status item state.
let state = StatusItemState(
    isEnabled: true,
    isAccessibilityTrusted: false,
    isScreenRecordingGranted: false
)
expect(state.isEnabled, "status item enabled flag")
expect(!state.isAccessibilityTrusted, "status item accessibility flag")
expect(!state.isScreenRecordingGranted, "status item screen recording flag")

// Selection text normalizer.
expect(SelectionTextNormalizer.clean(nil) == nil, "nil selected text")
expect(SelectionTextNormalizer.clean("   \n\t  ") == nil, "empty selected text")
expect(SelectionTextNormalizer.clean("  hello  ") == "hello", "trimmed selected text")

// Voice HUD pure logic: mic RMS is clamped and normalized for animation.
expect(VoiceLevelMeter.normalizedRMS(-1) == 0, "voice level rejects invalid low RMS")
expect(VoiceLevelMeter.normalizedRMS(0.012) == 0, "voice level noise floor")
expect(VoiceLevelMeter.normalizedRMS(0.22) == 1, "voice level speech ceiling")
expect(
    VoiceCaptureFinalization.timeoutNanoseconds(hasTranscript: true, heardSpeech: false) == 800_000_000,
    "voice finalization uses short timeout once transcript exists"
)
expect(
    VoiceCaptureFinalization.timeoutNanoseconds(hasTranscript: false, heardSpeech: true) == 1_800_000_000,
    "voice finalization waits for short speech without transcript"
)
expect(
    VoiceCaptureFinalization.timeoutNanoseconds(hasTranscript: false, heardSpeech: false) == 350_000_000,
    "voice finalization exits quickly for silence"
)
expect(
    VoiceCaptureFinalization.timeoutNanoseconds(transcript: "spin", heardSpeech: true) == 1_800_000_000,
    "voice finalization waits longer for one-word partials after speech"
)
expect(
    VoiceCaptureFinalization.timeoutNanoseconds(transcript: "spin up", heardSpeech: true) == 800_000_000,
    "voice finalization exits quickly once a multi-word command exists"
)
expect(
    !VoiceCaptureFinalization.shouldFinishOnRecognitionError(hasTranscript: false, heardSpeech: true),
    "voice finalization ignores early empty error after heard speech"
)
expect(
    VoiceRecognitionConfiguration().localeIdentifier == "en_US",
    "voice recognition uses stable English command locale"
)
expect(
    VoiceRecognitionConfiguration.defaultContextualStrings.isEmpty,
    "voice recognition does not bias general dictation by default"
)
expect(
    VoiceRecognitionConfiguration.normalizedContextualStrings([" Codex ", "codex", "Ghostty"]) == [
        "Codex",
        "Ghostty"
    ],
    "voice recognition contextual strings are cleaned and deduplicated"
)

// Phase 2 router: deterministic seed rules map to stable intent kinds and slots.
let router = DeterministicRouter()

let searchIntent = await router.route("Get me the best restaurants from Google")
expect(searchIntent.kind == .browserSearch, "search routes to browserSearch")
expect(searchIntent.slots["query"] == "the best restaurants", "search captures query")
expect(searchIntent.slots["engine"] == "google", "search captures engine")
expect(searchIntent.confidence == 1, "deterministic search confidence")

let swarmIntent = await router.route("Spin up five agents and refactor the UI docs")
expect(swarmIntent.kind == .agentSwarm, "agent phrase routes to agentSwarm")
expect(swarmIntent.slots["count"] == "5", "agent phrase normalizes spoken count")
expect(swarmIntent.slots["task"] == "the ui docs", "agent phrase captures task")

let naturalSwarmIntent = await router.route("Spin up 3 agents on casprflow for UI docs, tests, and cleanup")
expect(naturalSwarmIntent.kind == .agentSwarm, "natural agent phrase routes to agentSwarm")
expect(naturalSwarmIntent.slots["count"] == "3", "natural agent phrase captures count")
expect(naturalSwarmIntent.slots["project"] == "casprflow", "natural agent phrase captures project")
expect(
    naturalSwarmIntent.slots["task"] == "ui docs, tests, and cleanup",
    "natural agent phrase captures task list"
)
let bareSwarmIntent = await router.route("Spin up 3 agents")
expect(bareSwarmIntent.kind == .agentSwarm, "bare agent phrase routes to agentSwarm")
expect(bareSwarmIntent.slots["count"] == "3", "bare agent phrase captures count")
expect(bareSwarmIntent.slots["task"] == nil, "bare agent phrase does not invent a task")

let replyIntent = await router.route("Reply to Prachi that we'll ship Friday")
expect(replyIntent.kind == .slackReply, "reply phrase routes to slackReply")
expect(replyIntent.slots["recipient"] == "prachi", "reply captures recipient")
expect(replyIntent.slots["message"] == "we'll ship friday", "reply captures message")

let openAppIntent = await router.route("Open Linear")
expect(openAppIntent.kind == .openApp, "open app phrase routes to openApp")
expect(openAppIntent.slots["app"] == "linear", "open app captures app")

let openURLIntent = await router.route("Go to example.com")
expect(openURLIntent.kind == .openURL, "domain phrase routes to openURL")
expect(openURLIntent.slots["url"] == "https://example.com", "domain phrase normalizes URL")

let shellIntent = await router.route("Run git status")
expect(shellIntent.kind == .shell, "run phrase routes to shell")
expect(shellIntent.slots["command"] == "git status", "run phrase captures command")

let unknownIntent = await router.route("Please do the thing")
expect(unknownIntent.kind == .unknown, "unmatched phrase routes to unknown")
expect(unknownIntent.confidence == 0, "unknown confidence")

// Phase 7 router: strict JSON parse + Tier-1 fallback only after Tier-0 misses.
let llmJSON = #"{"kind":"browserSearch","slots":{"query":"quarterly revenue dashboard","engine":"google"},"confidence":0.86}"#
let parsedLLMIntent = try LLMRouter.parseIntentJSON(llmJSON, rawText: "pull up the quarterly revenue dashboard")
expect(parsedLLMIntent.kind == .browserSearch, "LLM router parses intent kind")
expect(parsedLLMIntent.slots["query"] == "quarterly revenue dashboard", "LLM router parses slots")
expect(parsedLLMIntent.confidence == 0.86, "LLM router parses confidence")
let llmJSONWithNullSlots = #"{"kind":"browserSearch","slots":{"query":"revenue dashboard","engine":"google","app":null},"confidence":0.91}"#
let parsedNullSlotIntent = try LLMRouter.parseIntentJSON(llmJSONWithNullSlots, rawText: "search revenue dashboard")
expect(parsedNullSlotIntent.slots["app"] == nil, "LLM router ignores null slots")
expect(parsedNullSlotIntent.slots["query"] == "revenue dashboard", "LLM router keeps populated nullable slots")
expect(
    ((LLMRouter.intentSchema["schema"] as? [String: Any])?["required"] as? [String]) == [
        "kind",
        "slots",
        "confidence"
    ],
    "LLM router schema requires stable fields"
)
let slotsSchema = ((LLMRouter.intentSchema["schema"] as? [String: Any])?["properties"] as? [String: Any])?["slots"] as? [String: Any]
expect(slotsSchema?["additionalProperties"] as? Bool == false, "LLM router schema keeps slots closed for strict mode")
expect(slotsSchema?["required"] as? [String] == LLMRouter.slotKeys, "LLM router schema requires explicit nullable slot keys")

private struct StubLLMCompleter: LLMCompleting {
    let response: String

    func complete(
        prompt: String,
        instructions: String,
        textFormat: [String: Any]?,
        maxOutputTokens: Int
    ) async throws -> String {
        response
    }
}

let tieredRouter = TieredIntentRouter(tier1: LLMRouter(client: StubLLMCompleter(response: llmJSON)))
let tier0Result = await tieredRouter.route("Open Linear")
expect(tier0Result.kind == .openApp, "tiered router keeps deterministic fast path")
let tier1Result = await tieredRouter.route("pull up the quarterly revenue dashboard")
expect(tier1Result.kind == .browserSearch, "tiered router uses LLM fallback for long tail")

private struct StubHandler: ActionHandler {
    let message: String

    func match(_ intent: Intent) -> Bool {
        intent.kind == .shell
    }

    func execute(_ intent: Intent) async throws -> ActionResult {
        ActionResult(ok: true, message: message)
    }
}

private struct StubReadOnlyCapability: Capability {
    let name = "inspect_state"
    let summary = "Inspect stub state."
    let sideEffect: SideEffect = .readOnly
    let parameters = CapabilitySchema(parameters: [
        CapabilityParameter(
            name: "target",
            type: "string",
            description: "Thing to inspect.",
            required: true
        ),
        CapabilityParameter(
            name: "limit",
            type: "number",
            description: "Optional result limit.",
            required: false
        )
    ])

    func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult {
        let target = call.string("target") ?? "unknown"
        return CapabilityResult(
            ok: true,
            message: "Inspected \(target)",
            observation: "Observed \(target)",
            data: [
                "target": .string(target),
                "count": .number(1)
            ]
        )
    }
}

private struct StubIntegerCapability: Capability {
    let name = "integer_param"
    let summary = "Validate integer args."
    let sideEffect: SideEffect = .readOnly
    let parameters = CapabilitySchema(parameters: [
        CapabilityParameter(
            name: "count",
            type: "integer",
            description: "Integer count.",
            required: true
        )
    ])

    func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult {
        CapabilityResult(ok: true, message: "Count \(call.int("count") ?? -1)")
    }
}

private struct CorruptArrayDecoder: Decoder {
    var codingPath: [any CodingKey] { [] }
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        throw DecodingError.typeMismatch(
            [String: JSONValue].self,
            DecodingError.Context(codingPath: [], debugDescription: "not keyed")
        )
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [JSONValue].self,
            DecodingError.Context(codingPath: [], debugDescription: "not unkeyed")
        )
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        CorruptArraySingleValueContainer()
    }
}

private struct CorruptArraySingleValueContainer: SingleValueDecodingContainer {
    var codingPath: [any CodingKey] { [] }

    func decodeNil() -> Bool { false }

    func decode(_ type: Bool.Type) throws -> Bool { throw typeMismatch(type) }
    func decode(_ type: String.Type) throws -> String { throw typeMismatch(type) }
    func decode(_ type: Double.Type) throws -> Double { throw typeMismatch(type) }
    func decode(_ type: Float.Type) throws -> Float { throw typeMismatch(type) }
    func decode(_ type: Int.Type) throws -> Int { throw typeMismatch(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { throw typeMismatch(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { throw typeMismatch(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { throw typeMismatch(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { throw typeMismatch(type) }
    func decode(_ type: UInt.Type) throws -> UInt { throw typeMismatch(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { throw typeMismatch(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { throw typeMismatch(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { throw typeMismatch(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { throw typeMismatch(type) }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        if type == [JSONValue].self {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "nested array failed")
            )
        }
        throw typeMismatch(type)
    }

    private func typeMismatch(_ type: Any.Type) -> DecodingError {
        DecodingError.typeMismatch(
            type,
            DecodingError.Context(codingPath: [], debugDescription: "wrong type")
        )
    }
}

private struct StubAppLauncher: AppLaunching {
    let result: ActionResult

    @MainActor
    func open(_ name: String) async throws -> ActionResult {
        result
    }
}

private struct StubShellRunner: ShellRunning {
    let result: ShellResult

    func runShell(_ command: String, cwd: URL?, timeout: TimeInterval) async throws -> ShellResult {
        result
    }
}

let registry = HandlerRegistry(handlers: [
    StubHandler(message: "first"),
    StubHandler(message: "second")
])
let registryResult = await registry.dispatch(shellIntent)
expect(registryResult.ok, "handler registry dispatch succeeds")
expect(registryResult.message == "first", "handler registry uses first matching handler")

// Phase 8 capability model: JSON values, strict schemas, registry validation, and executor wrappers.
let jsonPayload = JSONValue.object([
    "name": .string("casprflow"),
    "count": .number(3),
    "enabled": .bool(true),
    "items": .array([.string("open_app"), .null]),
    "meta": .object(["tier": .number(1)])
])
expect(JSONValue.number(42).intValue == 42, "JSONValue intValue accepts in-range integers")
expect(JSONValue.number(1.5).intValue == nil, "JSONValue intValue rejects fractional numbers")
expect(JSONValue.number(1e20).intValue == nil, "JSONValue intValue rejects out-of-range integers")
expect(JSONValue.number(Double.infinity).intValue == nil, "JSONValue intValue rejects non-finite numbers")
let encodedJSONValue = try JSONEncoder().encode(jsonPayload)
let decodedJSONValue = try JSONDecoder().decode(JSONValue.self, from: encodedJSONValue)
expect(decodedJSONValue == jsonPayload, "JSONValue round-trips through Codable")
do {
    _ = try JSONValue(from: CorruptArrayDecoder())
    expect(false, "JSONValue decoder should propagate nested data corruption")
} catch DecodingError.dataCorrupted(let context) {
    expect(
        context.debugDescription == "nested array failed",
        "JSONValue decoder preserves nested decoding errors"
    )
}
let jsonAnyRoundTrip = JSONValue(any: jsonPayload.anyValue)
expect(jsonAnyRoundTrip == jsonPayload, "JSONValue round-trips through Any")
let rawDictionary: [String: Any] = [
    "title": "phase 8",
    "required": true,
    "depth": 2,
    "nested": ["ok": true],
    "array": ["one", 2],
    "empty": NSNull()
]
guard let jsonDictionary = JSONValue.dictionary(from: rawDictionary) else {
    expect(false, "JSONValue builds dictionary from [String: Any]")
    exit(1)
}
let anyDictionary = JSONValue.anyDictionary(from: jsonDictionary)
let rebuiltDictionary = JSONValue.dictionary(from: anyDictionary)
expect(rebuiltDictionary == jsonDictionary, "JSONValue round-trips [String: Any] both ways")

let capabilitySchema = CapabilitySchema(parameters: [
    CapabilityParameter(name: "query", type: "string", description: "Search query.", required: true),
    CapabilityParameter(name: "limit", type: "number", description: "Optional limit.", required: false)
])
let jsonSchema = capabilitySchema.jsonSchema()
expect(jsonSchema["type"] as? String == "object", "capability schema emits object type")
expect(jsonSchema["additionalProperties"] as? Bool == false, "capability schema is closed")
expect(jsonSchema["required"] as? [String] == ["query"], "capability schema only requires required params")
let schemaProperties = jsonSchema["properties"] as? [String: Any]
let queryProperty = schemaProperties?["query"] as? [String: Any]
let limitProperty = schemaProperties?["limit"] as? [String: Any]
expect(queryProperty?["type"] as? String == "string", "capability schema includes query type")
expect(limitProperty?["type"] as? String == "number", "capability schema includes optional param type")

let capabilityContext = ExecutionContext(rawText: "inspect state")
let capabilityRegistry = CapabilityRegistry([StubReadOnlyCapability()])
let capabilityCatalog = capabilityRegistry.catalog()
expect(capabilityCatalog.count == 1, "capability registry catalog includes registered capability")
expect(capabilityCatalog[0].name == "inspect_state", "capability registry catalog includes capability name")
expect(capabilityCatalog[0].sideEffect == .readOnly, "capability registry catalog includes side effect")
expect(
    capabilityCatalog[0].schema["additionalProperties"] as? Bool == false,
    "capability registry catalog exposes strict schema"
)
expect(
    capabilityRegistry.fastMatch("inspect state") == nil,
    "capability registry fastMatch is nil without capability matchers"
)
let unknownCapabilityResult = await capabilityRegistry.dispatch(
    CapabilityCall(capability: "missing_capability"),
    context: capabilityContext
)
expect(!unknownCapabilityResult.ok, "capability registry rejects unknown capability")
expect(
    unknownCapabilityResult.message == "Unknown capability: missing_capability.",
    "capability registry unknown message is clear"
)
let missingArgumentResult = await capabilityRegistry.dispatch(
    CapabilityCall(capability: "inspect_state"),
    context: capabilityContext
)
expect(!missingArgumentResult.ok, "capability registry rejects missing required arg")
expect(
    missingArgumentResult.message == "Missing required argument 'target' for capability inspect_state.",
    "capability registry missing arg message is clear"
)
let readOnlyResult = await capabilityRegistry.dispatch(
    CapabilityCall(capability: "inspect_state", arguments: ["target": .string("cache")]),
    context: capabilityContext
)
expect(readOnlyResult.ok, "stub read-only capability dispatch succeeds")
expect(readOnlyResult.observation == "Observed cache", "stub read-only capability returns observation")
expect(readOnlyResult.data["target"] == .string("cache"), "stub read-only capability returns data")
let integerRegistry = CapabilityRegistry([StubIntegerCapability()])
let validIntegerResult = await integerRegistry.dispatch(
    CapabilityCall(capability: "integer_param", arguments: ["count": .number(3)]),
    context: capabilityContext
)
expect(validIntegerResult.ok, "capability registry accepts integer schema type")
let invalidIntegerResult = await integerRegistry.dispatch(
    CapabilityCall(capability: "integer_param", arguments: ["count": .number(3.5)]),
    context: capabilityContext
)
expect(!invalidIntegerResult.ok, "capability registry rejects fractional integer args")

let appAction = ActionResult(ok: true, message: "Opened Linear")
let legacyOpenAppResult = try await OpenAppHandler(
    launcher: StubAppLauncher(result: appAction)
).execute(openAppIntent)
let capabilityOpenAppResult = try await OpenAppCapability(
    launcher: StubAppLauncher(result: appAction)
).execute(
    CapabilityCall(capability: "open_app", arguments: ["app": .string("linear")]),
    context: capabilityContext
)
expect(
    capabilityOpenAppResult.actionResult == legacyOpenAppResult,
    "OpenAppCapability produces the legacy ActionResult shape"
)

let shellStubResult = ShellResult(exitCode: 0, stdout: "## main\n", stderr: "")
let legacyShellResult = try await ShellCommandHandler(
    runner: StubShellRunner(result: shellStubResult)
).execute(shellIntent)
let capabilityShellResult = try await RunShellCapability(
    runner: StubShellRunner(result: shellStubResult)
).execute(
    CapabilityCall(capability: "run_shell", arguments: ["command": .string("git status")]),
    context: capabilityContext
)
expect(
    capabilityShellResult.actionResult == legacyShellResult,
    "RunShellCapability produces the legacy ActionResult shape"
)

// Phase 3 executors: pure builders/resolvers stay stable for generic handlers.
let googleURL = BrowserSearchURLBuilder.googleSearchURL(query: "best restaurants in SF")
expect(
    googleURL?.absoluteString == "https://www.google.com/search?q=best%20restaurants%20in%20SF",
    "browser search URL builder encodes query"
)
expect(
    BrowserSearchURLBuilder.googleSearchURL(query: "   ") == nil,
    "browser search URL builder rejects empty query"
)
expect(
    AppNameResolver.normalizedName("  Figma App  ") == "figma",
    "app resolver normalizes spoken app names"
)
expect(
    AppNameResolver.bundleIdentifier(for: "google chrome") == "com.google.Chrome",
    "app resolver maps common browser name"
)
expect(
    AppNameResolver.candidateApplicationNames(for: "figma").contains("Figma.app"),
    "app resolver includes .app candidate"
)
expect(ShellCommandPolicy.isAllowed("git status --short"), "shell policy allows safe git status")
expect(!ShellCommandPolicy.isAllowed("rm -rf /"), "shell policy blocks destructive command")
expect(!ShellCommandPolicy.isAllowed("echo ok; rm -rf /"), "shell policy blocks shell chaining")
expect(!ShellCommandPolicy.isAllowed("git status\nrm -rf /"), "shell policy blocks newline chaining")
expect(!ShellCommandPolicy.isAllowed("git status\rrm -rf /"), "shell policy blocks carriage-return chaining")

// Phase 4 swarm: project resolution, task slicing, per-pane prompts, and Warp URL/YAML.
let repoURL = URL(fileURLWithPath: "/tmp/CasprFlow").standardizedFileURL
let aliasStoreURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("casprflow-checks-\(UUID().uuidString)")
    .appendingPathComponent("aliases.json")
let projectResolver = ProjectResolver(
    defaultProjectURL: repoURL,
    aliases: ["casprflow": repoURL],
    searchRoots: [],
    aliasStore: ProjectAliasStore(fileURL: aliasStoreURL)
)
expect(ProjectResolver.normalizedName("The CasprFlow repo") == "casprflow", "project resolver normalizes names")
let currentProjectURL = try projectResolver.resolve(project: "this project folder")
expect(
    currentProjectURL.path == repoURL.path,
    "project resolver supports current project reference"
)
let aliasedProjectURL = try projectResolver.resolve(project: "casprflow")
expect(
    aliasedProjectURL.path == repoURL.path,
    "project resolver supports aliases"
)
let aliasStore = ProjectAliasStore(fileURL: aliasStoreURL)
try aliasStore.saveAlias("casper flow", projectURL: repoURL)
let speechAliasProjectURL = try projectResolver.resolve(project: "casper flow")
expect(
    speechAliasProjectURL.path == repoURL.path,
    "project resolver supports learned speech alias"
)
expect(
    ProjectResolver.isLikelySameName("casperflow", "casprflow"),
    "project resolver identifies likely speech spelling drift"
)
let fuzzyRoot = FileManager.default.temporaryDirectory
    .appendingPathComponent("casprflow-fuzzy-\(UUID().uuidString)", isDirectory: true)
let fuzzyProject = fuzzyRoot.appendingPathComponent("CasprFlow", isDirectory: true)
try FileManager.default.createDirectory(at: fuzzyProject, withIntermediateDirectories: true)
let fuzzyResolver = ProjectResolver(
    defaultProjectURL: repoURL,
    aliases: [:],
    searchRoots: [fuzzyRoot],
    aliasStore: ProjectAliasStore(fileURL: fuzzyRoot.appendingPathComponent("aliases.json"))
)
do {
    _ = try fuzzyResolver.resolve(project: "casper flow")
    expect(false, "fuzzy project requires clarification before aliasing")
} catch SwarmHostError.projectNeedsClarification(let spokenName, let candidates) {
    expect(spokenName == "casper flow", "fuzzy resolver preserves spoken name")
    expect(candidates.contains(fuzzyProject.path), "fuzzy resolver returns candidate path")
}
expect(
    ProjectResolver.shouldSkipSearchDirectory(URL(fileURLWithPath: "/tmp/node_modules")),
    "project resolver skips dependency directories during search"
)
let skippedRoot = FileManager.default.temporaryDirectory
    .appendingPathComponent("casprflow-skipped-\(UUID().uuidString)", isDirectory: true)
let skippedProject = skippedRoot
    .appendingPathComponent("node_modules", isDirectory: true)
    .appendingPathComponent("CasprFlow", isDirectory: true)
try FileManager.default.createDirectory(at: skippedProject, withIntermediateDirectories: true)
let skippedResolver = ProjectResolver(
    defaultProjectURL: URL(fileURLWithPath: "/tmp/DefaultProject"),
    aliases: [:],
    searchRoots: [skippedRoot],
    aliasStore: ProjectAliasStore(fileURL: skippedRoot.appendingPathComponent("aliases.json"))
)
do {
    _ = try skippedResolver.resolve(project: "CasprFlow")
    expect(false, "project resolver should not search dependency directories")
} catch SwarmHostError.projectNotFound(let project) {
    expect(project == "CasprFlow", "project resolver skips dependency directory matches")
}
expect(
    SwarmTaskSplitter.slices(from: "ui docs, tests, and cleanup", expectedCount: 3) == [
        "ui docs",
        "tests",
        "cleanup"
    ],
    "swarm task splitter maps listed tasks to panes"
)
expect(
    SwarmTaskSplitter.slices(from: "ui docs, tests and cleanup", expectedCount: 3) == [
        "ui docs",
        "tests",
        "cleanup"
    ],
    "swarm task splitter maps mixed comma/and tasks to panes"
)
expect(
    SwarmTaskSplitter.slices(from: "ui docs plus tests plus cleanup", expectedCount: 3) == [
        "ui docs",
        "tests",
        "cleanup"
    ],
    "swarm task splitter maps plus-separated tasks to panes"
)
expect(SwarmSpecBuilder.agentCount(from: "12", maxAgents: 10) == 10, "swarm count clamps high")
expect(SwarmSpecBuilder.agentCount(from: "0", maxAgents: 10) == 1, "swarm count clamps low")
expect(SwarmSpecBuilder.agentCount(from: "three", maxAgents: 10) == 3, "swarm count accepts spoken numbers")
let defaultSwarmTool = try SwarmAgentTool.from(slot: nil)
expect(defaultSwarmTool == .codex, "swarm defaults to codex")
expect(ShellQuoter.quote("it's ready") == "'it'\\''s ready'", "shell quoter escapes single quotes")
expect(
    SwarmAgentTool.codex.command(toolPath: "/tmp/codex", prompt: nil) == "'/tmp/codex'",
    "codex swarm command supports plain interactive launch"
)

let swarmBuilder = SwarmSpecBuilder(
    projectResolver: projectResolver,
    validateToolExists: false,
    toolPathProvider: { tool in
        switch tool {
        case .claude:
            return "/tmp/claude"
        case .codex:
            return "/tmp/codex"
        }
    }
)
let swarmSpec = try swarmBuilder.build(from: naturalSwarmIntent)
expect(swarmSpec.name == "CasprFlow Swarm", "swarm spec names the resolved project")
expect(swarmSpec.panes.count == 3, "swarm spec creates requested pane count")
expect(swarmSpec.panes[0].cwd.path == repoURL.path, "swarm pane uses resolved cwd")
expect(swarmSpec.panes[0].title == "Agent 1: ui docs", "swarm pane title uses owned task")
expect(swarmSpec.panes[1].command.contains("Owned task: tests."), "swarm pane prompt includes owned task")
expect(swarmSpec.panes[2].command.contains("Owned task: cleanup."), "swarm pane prompt includes final owned task")
expect(swarmSpec.panes[0].command.contains("Full user intent: Spin up 3 agents"), "swarm prompt keeps full intent")
expect(swarmSpec.panes[0].command.contains("You are agent 1 of 3."), "swarm prompt includes agent index")
expect(
    swarmSpec.panes[0].command.hasPrefix("cd '/tmp/CasprFlow' && '/tmp/codex' "),
    "swarm command expands cwd and interactive codex"
)
let plainSwarmSpec = try swarmBuilder.build(from: bareSwarmIntent)
expect(plainSwarmSpec.panes.count == 3, "plain swarm creates requested pane count")
expect(
    plainSwarmSpec.panes.map(\.command) == Array(repeating: "cd '/tmp/CasprFlow' && '/tmp/codex'", count: 3),
    "plain swarm opens codex with no seeded prompt"
)
expect(
    plainSwarmSpec.panes.map(\.title) == ["Agent 1/3", "Agent 2/3", "Agent 3/3"],
    "plain swarm uses generic pane titles"
)
expect(
    GhosttyHost.splitPlan(forPaneIndex: 2) == GhosttySplitPlan(targetPaneIndex: 1, direction: "right"),
    "ghostty host splits second pane to the right"
)
expect(
    GhosttyHost.splitPlan(forPaneIndex: 3) == GhosttySplitPlan(targetPaneIndex: 1, direction: "down"),
    "ghostty host splits third pane below the first"
)
expect(
    AppleScriptQuoter.quote("say \"hi\"\n") == "\"say \\\"hi\\\"\\n\"",
    "AppleScript quoter escapes quotes and newlines"
)
let ghosttyScript = try GhosttyHost.appleScript(for: swarmSpec)
expect(ghosttyScript.contains("tell application \"Ghostty\""), "ghostty script targets Ghostty")
expect(ghosttyScript.contains("set win to new window with configuration cfg1"), "ghostty script creates window")
expect(
    ghosttyScript.contains("set pane2 to split pane1 direction right with configuration cfg2"),
    "ghostty script creates second pane"
)
expect(
    ghosttyScript.contains("set pane3 to split pane1 direction down with configuration cfg3"),
    "ghostty script creates third pane"
)
expect(
    ghosttyScript.contains("input text \"cd '/tmp/CasprFlow' && '/tmp/codex' "),
    "ghostty script sends expanded command text"
)

let warpWriter = WarpLaunchConfigWriter()
let warpYAML = try warpWriter.yaml(for: swarmSpec)
expect(warpYAML.contains("split_direction: vertical"), "warp yaml uses split layout")
expect(warpYAML.contains("Agent 1: ui docs"), "warp yaml includes pane title")
expect(warpYAML.contains("commands:"), "warp yaml includes commands")
let tmuxSession = TmuxSessionNamer().sessionName(
    for: swarmSpec,
    timestamp: Date(timeIntervalSince1970: 1_779_917_948)
)
expect(tmuxSession == "casprflow-swarm-1779917948", "tmux session namer builds stable slug")
expect(
    TmuxHost.attachCommand(tmuxPath: "/opt/homebrew/bin/tmux", session: tmuxSession) ==
        "'/opt/homebrew/bin/tmux' attach-session -t 'casprflow-swarm-1779917948'",
    "tmux host builds attach command"
)

// LLM connector: config load + request body shape.
let config = LLMConfig.load(environment: ["OPENAI_MODEL": "gpt-test", "OPENAI_REASONING_EFFORT": "medium"])
expect(config.model == "gpt-test", "config reads OPENAI_MODEL")
expect(config.reasoningEffort == "medium", "config reads OPENAI_REASONING_EFFORT")

let body = LLMClient.requestBody(
    model: "gpt-test",
    prompt: "hi",
    instructions: "be terse",
    textFormat: nil,
    maxOutputTokens: 32,
    reasoningEffort: "low"
)
expect(body["model"] as? String == "gpt-test", "request body carries model")
expect(body["store"] as? Bool == false, "request body does not store")
expect(JSONSerialization.isValidJSONObject(body), "request body is valid JSON")

// Output extraction from a Responses-style payload.
let sample = """
{"output":[{"content":[{"type":"output_text","text":"open chrome"}]}]}
""".data(using: .utf8)!
expect(LLMClient.extractOutputText(from: sample) == "open chrome", "extracts output text")

print("CasprFlow checks passed")

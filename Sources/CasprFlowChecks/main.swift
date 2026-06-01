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

let registry = HandlerRegistry(handlers: [
    StubHandler(message: "first"),
    StubHandler(message: "second")
])
let registryResult = await registry.dispatch(shellIntent)
expect(registryResult.ok, "handler registry dispatch succeeds")
expect(registryResult.message == "first", "handler registry uses first matching handler")

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

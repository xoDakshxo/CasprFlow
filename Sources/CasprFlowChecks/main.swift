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
    !VoiceCaptureFinalization.shouldFinishOnRecognitionError(hasTranscript: false, heardSpeech: true),
    "voice finalization ignores early empty error after heard speech"
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

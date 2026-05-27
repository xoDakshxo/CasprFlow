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

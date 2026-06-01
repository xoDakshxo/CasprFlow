# Phase 14 — control_ui: vision fallback (computer-use)

## Goal

Complete the tier-3 escape hatch: when the Accessibility path (phase 13) can't reach the
target, fall back to **vision** — screenshot → `ComputerUseModel` → screen-coordinate
action via `CGEvent` → screenshot → loop, until done or the step budget is hit. This is
the **last resort**, gated on config, and the **only** path allowed to be visibly slow
(D2, D11, latency contract). With no vision key configured, `control_ui` stays AX-only and
reports honestly.

## Build

`Sources/CasprFlowCore/ControlUI/ComputerUseModel.swift`:

```swift
public struct ScreenObservation: Sendable {
    public let pngData: Data
    public let pointSize: CGSize     // logical points
    public let pixelSize: CGSize     // backing pixels (Retina scale)
}
public enum ComputerAction: Equatable, Sendable {
    case click(x: Double, y: Double)         // in logical points
    case type(String)
    case key(String)                         // e.g. "return", "cmd+v"
    case scroll(dx: Double, dy: Double)
    case done(summary: String)
    case failed(reason: String)
}
public protocol ComputerUseModel: Sendable {
    func nextAction(goal: String,
                    observation: ScreenObservation,
                    history: [ComputerAction]) async throws -> ComputerAction
}
```

`Sources/CasprFlowCore/ControlUI/AnthropicComputerUse.swift` — default impl using the
Anthropic computer-use tool. Separate client/key from the OpenAI planner (D4).

`Sources/CasprFlowCore/ControlUI/ScreenCapturer.swift` — screenshot the target window/
display (ScreenCaptureKit preferred; `CGWindowListCreateImage` acceptable) using the
existing **Screen Recording** permission.

`Sources/CasprFlowCore/ControlUI/EventSynthesizer.swift` — perform a `ComputerAction` with
`CGEvent` (mouse move+click, key/type, scroll). Pure coordinate math (point→pixel, target-
window origin offset) lives here and is **unit-tested**.

### Wire into `control_ui`

Extend `ControlUICapability.execute`:

1. Try the **AX path** (phase 13). On success, return — vision never runs.
2. On AX failure **and** a configured vision key: run the vision loop:
   - capture `ScreenObservation` (scoped to the target window when possible),
   - `model.nextAction(goal:observation:history:)`,
   - map + perform via `EventSynthesizer`, append to history,
   - re-capture, loop until `.done`, `.failed`, or `maxVisionSteps` (small, e.g. 12) or a
     wall-clock ceiling.
3. On AX failure **and no** vision key: return the AX failure + a note that vision is
   unconfigured. Never silently do nothing.

### Gates + safety (non-negotiable)

- **Confirm before consequential clicks.** The vision loop runs under the same confirm
  gate (D8/D13): outward/irreversible actions pause for approval. A simple model is to
  require confirm before the **first** action of any vision session, and again before any
  action the model flags as a submit/send. Keep the human in control.
- **HUD shows "working" the entire time** — this path is acknowledged-slow; never pretend
  it's instant.
- **Step + time budget**; on exhaustion, report partial progress honestly.
- **Cancellable** via Escape (cooperative).
- The model only receives the screenshot + goal + action history — no extra data
  exfiltration. Document this.

### Config

Add to `LLMConfig`/`casprflow.config.local.json`: `anthropic_api_key`,
`computer_use_model` (default the current Anthropic computer-use model), and a
`computer_use_enabled` flag (default true when a key is present). Preconnect the vision
endpoint at launch (latency tactic) only if enabled.

## Reuse

- The existing **Screen Recording** permission stack (+ drag-into-Settings flow).
- Phase 13 `AccessibilityDriver` as the primary path.
- `LLMClient` patterns for HTTP/JSON (a sibling Anthropic client, not a fork of the OpenAI
  one — keep them separate, D4).

## Latency budget

- AX path still **< 150 ms** and still tried first — vision must not regress it.
- Vision actions: seconds each, **acknowledged-slow**, rare by construction. The budget is
  "don't be reached when a programmatic or AX path exists", enforced by ordering, not by
  speed.
- `EventSynthesizer` coordinate math and `ScreenObservation` scaling are synchronous and
  trivial — `< 1 ms`.

## Acceptance

- `swift build` green; `CasprFlowChecks` passes — **no live network, no real clicks**.
- New `CasprFlowChecks` assertions (pure logic + stub `ComputerUseModel`):
  - point→pixel scaling and target-window origin offset compute correct device coords for
    a Retina (2x) and non-Retina case.
  - The vision loop with a scripted stub model (`click`, `type`, `done`) performs actions
    in order (via a stubbed/`EventSynthesizer` spy) and ends on `done`.
  - `maxVisionSteps` caps a non-finishing loop; reports partial progress.
  - With no vision key, `control_ui` after an AX miss returns the AX failure + unconfigured
    note (vision loop not entered).
  - Confirm gate blocks the first vision action when `confirm → false`.
- Manual smoke (Accessibility + Screen Recording granted, vision key set): a `control_ui`
  task whose target AX can't resolve falls to vision, asks confirm, then drives the UI;
  the HUD shows working throughout; Escape cancels.

## Out of scope

- Making vision fast (it isn't, by design) or default (it must stay last). No new
  user-facing surface beyond `control_ui` gaining the fallback.

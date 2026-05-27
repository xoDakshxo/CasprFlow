# Phase 2 — Intent router + handler registry

## Goal

Turn a transcript string into a dispatched action. Build the `Intent` model, the
deterministic Tier-0 router, the `ActionHandler` protocol + `HandlerRegistry`, and the
dispatch loop. No LLM yet (that's phase 7) — Tier-0 covers the known shapes.

## Build

- `Sources/CasprFlowCore/Routing/Intent.swift` — `IntentKind` enum + `Intent` struct
  (see [`../architecture.md`](../architecture.md#intent-model-target-shape)). Keep the
  enum open to growth; prefer the generic kinds (`openApp`, `openURL`, `shell`).
- `Sources/CasprFlowCore/Routing/IntentRouter.swift` — `DeterministicRouter` that maps a
  normalized transcript to an `Intent` via ordered regex/keyword rules. Returns
  `.unknown` on no match (phase 7 adds the LLM fallback behind the same `route` call).
- `Sources/CasprFlowCore/Handlers/ActionHandler.swift` — the protocol + `HandlerRegistry`.

## Contracts

```swift
protocol IntentRouter {
    func route(_ text: String) async -> Intent
}

protocol ActionHandler {
    func match(_ intent: Intent) -> Bool
    func execute(_ intent: Intent) async throws -> ActionResult
}

struct ActionResult {
    let ok: Bool
    let message: String?   // optional brief toast text
}

@MainActor
final class HandlerRegistry {
    init(handlers: [ActionHandler])
    func dispatch(_ intent: Intent) async -> ActionResult   // first match wins
}
```

## Deterministic rules (seed set)

Normalize first (lowercase, trim, collapse whitespace). Then, in order:

- `^(get me|show me) (?<query>.+) from google` → `.browserSearch` (`engine=google`)
- `^(search|google|look up|find) (?<query>.+)` → `.browserSearch`
- `^(spin up|start|launch) (?<count>\d+|a|one|two|…) agents?.* (refactor|fix|do|build) (?<task>.+)` → `.agentSwarm`
- `^(reply|respond|tell|message)( to)? (?<recipient>\w+) (that |saying |with )?(?<message>.+)` → `.slackReply`
- `^(open|launch|go to) (?<app>.+)` → `.openApp` (or `.openURL` if it parses as a URL/domain)
- `^(run|execute) (?<command>.+)` → `.shell`
- else → `.unknown`

Keep rules data-driven and easy to extend. Spoken numbers ("five") → digits.

## Wire-up

`VoiceHUDController.onTranscript` → `router.route(text)` → `registry.dispatch(intent)`.
Show the spinner during `route`+`dispatch`; on result, dismiss the HUD (or flash a
toast). For `.unknown`, show a brief "didn't catch that" HUD state. Until phase 3 adds
real handlers, the app registry uses a visible logging stub handler (`Routed: <kind>`)
so recognized intents prove the dispatch loop without performing external actions.

## Reuse

- `SelectionTextNormalizer.clean(_:)` for transcript tidy-up.
- Add unit assertions to `CasprFlowChecks` for the router: each seed rule maps a sample
  phrase to the right kind + slots. This is pure logic — easy to test headlessly.

## Acceptance

- Speaking each seed phrase produces the right `Intent` (assert in checks).
- `HandlerRegistry.dispatch` calls the first matching handler (use a stub handler until
  phase 3).
- `swift build` green, `CasprFlowChecks` passes with new router assertions.

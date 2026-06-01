# Phase 11 — Orchestrator + gates + speculative planning

## Goal

Wire the brain together and into the live app. The `Orchestrator` replaces
`routeAndDispatch`: FastRouter → (miss) Planner → execute the plan's steps in order,
threading results, with **clarify** and **confirm** gates (D13) and **never auto-send**
(D8). Add **speculative planning** so the planner round-trip overlaps the user's speech
and the common planned path still feels instant (D0). This is the phase that makes the
whole v3 model real.

## Build

`Sources/CasprFlowCore/Routing/Orchestrator.swift`:

```swift
@MainActor
public final class Orchestrator {
    public init(registry: CapabilityRegistry,
                fastRouter: FastRouter,
                planner: Planner)

    /// Final transcript → execute. Used on hotkey release.
    public func handle(_ transcript: String,
                       clarify: @escaping @Sendable (String) async -> String?,
                       confirm: @escaping @Sendable (String) async -> Bool) async -> ActionResult

    /// Speculative: called with a STABLE partial while the user still holds.
    /// If FastRouter doesn't claim it, kick off the planner and cache the in-flight task.
    public func speculate(on partial: String, context: PlannerContext)

    /// Cancel a speculation whose partial no longer matches (user kept talking).
    public func cancelSpeculation()
}
```

### Execution algorithm (`handle`)

1. **FastRouter first.** `fastRouter.route(transcript)` → if a one-step plan, execute it
   and return. Zero network, the common path.
2. **Planner on miss.** Reuse the **speculative** result if one is in flight for a
   matching partial (see below); otherwise call `planner.plan(transcript, …)` now.
3. **Empty plan** → return a friendly "Didn't catch that" `ActionResult(ok: false)`.
4. **Execute steps in order** via `registry.dispatch`, building an `ExecutionContext`
   whose `priorResults` accumulates each `CapabilityResult` so a later step can read an
   earlier step's `data`.
   - **Confirm gate:** before executing a `.confirm` capability, call the `confirm` hook
     with a human summary ("Send 'we ship Friday' to Prachi?"). If declined, stop and
     report. Outward actions are never auto-performed.
   - **Clarify gate:** if a step is missing a required arg the capability can resolve via
     clarify, call the `clarify` hook (one prompt), fill the arg, continue. Reuse the
     `ProjectClarificationService` pattern; persist learned answers (aliases) as today.
   - **Stop-on-failure:** if a step fails, stop the plan and surface that step's message
     (don't blindly run later steps that depended on it).
5. Return the last meaningful `ActionResult` for the HUD.

### Speculative planning (the latency win)

- `VoiceInputService` already streams partials. In `VoiceHUDController`/`AppCoordinator`,
  when a partial is **stable** (unchanged for a short debounce, e.g. ~250 ms) and
  non-trivial, call `orchestrator.speculate(on: partial, …)`.
- `speculate`: run `fastRouter.route(partial)`; if it **hits**, do nothing (release will
  be instant anyway). If it **misses**, start `planner.plan(partial)` as a cached
  `Task`, keyed by the normalized partial.
- On release, `handle` checks: is there a cached speculation whose key matches the final
  transcript (normalized)? If yes, `await` that task instead of starting a new request —
  the model round-trip already overlapped the speech.
- If the partial changed materially before release, `cancelSpeculation()` and plan fresh.
- Guard: never let speculation execute side-effects — it only *plans*. Execution happens
  on release after the (optional) confirm gate.

### Wire into `AppCoordinator`

- Replace the `intentRouter` + `handlerRegistry` + `routeAndDispatch` with the
  `Orchestrator`. Build the `CapabilityRegistry` from the seed capabilities (phase 8) with
  `fastMatch` (phase 9).
- `routeAndDispatch(transcript)` becomes `orchestrator.handle(transcript, clarify:, confirm:)`.
  Provide `clarify`/`confirm` closures that drive HUD prompts (see below).
- Keep the existing latency logging (`release → route-done → dispatch-done`); add
  `plan-done`, the **tier taken** (`fastRouter` | `planner`), and **speculation hit/miss**.
- Delete the now-unused `TieredIntentRouter`, `LLMRouter`, `DeterministicRouter`,
  `IntentRouter`, `Intent`, `ActionHandler`/`HandlerRegistry`, and the old handler files —
  their logic now lives in capabilities. (Do the deletion here so the tree has one brain.)

### HUD: clarify + confirm states

Extend `VoiceHUDController`/`VoiceHUDModel` (or a small native prompt) with two states:

- **clarify**: show the question, accept a short voice or click answer, return a string.
  For project ambiguity, reuse `ProjectClarificationService`.
- **confirm**: show the summary + an explicit approve/cancel. Default focus = cancel for
  outward actions. Return a bool.

Keep these gates **off** the tier-1 happy path — they only appear when a capability needs
them.

## Reuse

- `VoiceHUDController`, `VoiceInputService` (partials → speculation), `FloatingPanel`,
  `ProjectClarificationService`, `AppCoordinator`, the latency logging scaffold.

## Latency budget

- FastRouter path unchanged: `release → dispatch-done` **< 150 ms** (excl. app launch).
- Planner path **with speculation hit**: feels sub-second — `handle` mostly `await`s an
  already-finishing task.
- Speculation must not block the UI or fire on every keystroke-partial — debounce, single
  in-flight task, cancellable.

## Acceptance

- `swift build` green; `CasprFlowChecks` passes.
- New `CasprFlowChecks` assertions (stub registry + stub planner, no network):
  - FastRouter hit → single capability dispatched, planner never called.
  - FastRouter miss → planner called; multi-step plan executes **in order**; later step
    sees earlier step's `data` in `priorResults`.
  - A `.confirm` capability with `confirm → false` does **not** execute and reports a
    cancel; with `confirm → true` it executes.
  - A missing required arg triggers the `clarify` hook exactly once and then proceeds.
  - Stop-on-failure: a failing step halts the plan; later steps don't run.
  - Speculation key match: a cached speculation for the final transcript is reused (assert
    the planner stub is invoked once, via the speculation, not twice).
- Manual smoke (live app, now on the new brain):
  - "open Linear", "search best restaurants", "spin up 3 agents …" still work (tier 1).
  - A long-tail multi-step phrase produces a plan and runs it.
  - "reply to Prachi that we ship Friday" pastes a draft and **waits** (confirm), never
    sends.
  - Latency log shows tier + speculation hit/miss; tier-1 stays < 150 ms.

## Out of scope

- The `TaskAgent` loop body (phase 12), `control_ui` (13–14), `ArtifactWindow` (15).
  Phase 11 may register a **stub** `run_task` capability that returns "not yet
  implemented" so plans referencing it degrade gracefully.

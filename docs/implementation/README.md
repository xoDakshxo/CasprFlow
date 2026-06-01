# Implementation plan — Agentic Orchestrator (v3)

This is the **execution source of truth**. Build one phase at a time, in order. Each
phase is a single shippable PR that compiles, keeps `CasprFlowChecks` green, and meets
its **latency budget**. Later phases assume the seams from earlier ones.

Read first, in order:
1. [`../architecture.md`](../architecture.md) — the plan→capabilities→agent model, the
   three execution tiers, the capability protocol.
2. [`../decisions.md`](../decisions.md) — locked choices (D0 latency governs; D2 revised:
   computer-use is the last tier; D9–D13 new).
3. [`../latency.md`](../latency.md) — **the contract every phase is graded against.**
4. [`../connectors.md`](../connectors.md) — the kept core to reuse, with file paths.
5. [`CODEX_PLAN.md`](CODEX_PLAN.md) — how to work, PR conventions, the per-phase review
   checklist the reviewer will use.

## The shift in one sentence

Replace *classify-into-fixed-enum → thin one-shot handler* with *wide deterministic
fast-path → (on miss) LLM planner → ordered capability calls*, where capabilities span
three tiers — programmatic, in-app agent loop, computer-use — and **the common path
never touches the network** (D0).

## Interaction model (unchanged)

Hold **Option+Space**, speak, release. The Wispr-style HUD streams the on-device
transcript, then transitions to the spinner while the orchestrator runs. No command text
box. The streaming partials now also drive **speculative planning** (phase 11). Two
interactive gates may appear — **clarify** (missing arg) and **confirm** (outward/
irreversible action) — and nowhere else (D13).

## Phases

| # | Phase | Builds | Proves | State |
|---|---|---|---|---|
| 1 | [Voice HUD](phase-1-voice-hud.md) | push-to-talk, on-device STT, transcript→spinner HUD | hold → transcript → release | **done** |
| 8 | [Capability model + registry](phase-8-capability-model.md) | `Capability`, `CapabilityCall/Result`, `JSONValue`, `CapabilityRegistry`, `ExecutionContext`; migrate existing executors to capabilities behind a shim | existing commands still dispatch, now via capabilities | |
| 9 | [Wide FastRouter](phase-9-fast-router.md) | `FastRouter` deterministic match → `CapabilityCall`, broadened command-family coverage + slot tolerance | most everyday commands route at **zero network, <2 ms** | |
| 10 | [Planner](phase-10-planner.md) | `Planner` (LLM) → ordered multi-step `Plan` from the capability catalog; strict JSON; stub-tested | the long tail becomes a real multi-step plan | |
| 11 | [Orchestrator + gates + speculation](phase-11-orchestrator.md) | `Orchestrator` (fast→plan→execute, thread results), clarify/confirm gates, **speculative planning**, wire into `AppCoordinator` | end-to-end agentic dispatch; planner latency hidden | |
| 12 | [TaskAgent](phase-12-task-agent.md) | in-app `run_task` observe→think→act loop over a capability subset; step budget; recursion guard | a multi-step desktop task runs to completion in-app | |
| 13 | [control_ui: Accessibility](phase-13-control-ui-accessibility.md) | `AccessibilityDriver` (read tree, find, press, set value) + `control_ui` AX path | drive an app with no CLI/URL scheme, locally, fast | |
| 14 | [control_ui: vision fallback](phase-14-control-ui-vision.md) | `ComputerUseModel` + Anthropic impl; screenshot→action→`CGEvent` loop; AX-first fallback | reach a target AX can't, gated + acknowledged-slow | |
| 15 | [Artifact window](phase-15-artifact-window.md) | `ArtifactWindow` primitive + `draft_artifact` + `paste_text` (the Prachi flow) | stream output to a floating panel, Run; never auto-send | |
| 16 | [Latency hardening + polish](phase-16-latency-polish.md) | telemetry (tier/speculation hit-rate), preconnect for vision, planner timeout→clarify, config, allowlists | budgets measured + held; graceful degradation | |

Build order is strict 8 → 16. Phases 8–11 are the **brain** (must land first and clean).
12 adds the agent loop. 13–14 add computer-use. 15 is the artifact flow. 16 hardens.

## Hard rules for every phase

- **Latency is acceptance, not aspiration.** Hit the tier budget in
  [`../latency.md`](../latency.md). A FastRouter hit-rate or tier-1 timing regression
  **fails the phase**.
- **Reuse, don't rewrite.** Wire into the kept core (`AppCoordinator`, `FloatingPanel`,
  `HotkeyService`, `PasteService`, `LLMClient`, executors, permission stack). See
  [`../connectors.md`](../connectors.md).
- **Keep it green.** End each phase with `swift build` passing and
  `swift run CasprFlowChecks` passing. Add a `CasprFlowChecks` assertion for **every**
  new pure-logic unit (matchers, schema shape, plan parse, AX selector match, coordinate
  math). Pure logic must be unit-testable without a live app or network.
- **Stub the network and the screen.** Planner, agent, and vision must be testable with
  injected stubs (`LLMCompleting`, `ComputerUseModel`) — no live calls in checks.
- **Never auto-send.** Outward/irreversible capabilities are `.confirm` (D8, D13).
- **Group code by role** under `Sources/CasprFlowCore/`: `Input/`, `Routing/`,
  `Capabilities/`, `Exec/`, `Agent/`, `ControlUI/`.
- **One phase per PR**, titled `[v3][Phase N] …`. Don't broaden scope or jump ahead.
- **Keep docs aligned.** If you change a seam, update the doc that would contradict it.

# Implementation plan

The dispatcher is built on top of the kept connector core (see
[`../connectors.md`](../connectors.md)) in ordered phases. Each phase is shippable,
compiles, and has an acceptance check. Build them in order — later phases assume the
seams from earlier ones.

**Guiding principle (read [`../decisions.md`](../decisions.md#d2b) first):** build
**universal executor primitives**, then compose **thin handlers** over them. The
reference handlers (browser search, agent swarm, Slack reply, SQL artifact) prove the
primitives; they are not the scope. Adding a capability = adding a handler, not new
plumbing. Keep app-specific knowledge at the edge.

## Interaction model (voice-first, no command text box)

There is **no command text field**. You press and **hold** Option+Space; a small Wispr-style
transcript pill appears center-bottom of the screen and updates with your words; you
**release**; the pill transitions into the existing **CasprFlow spinner** while the
transcript is routed and dispatched. If the utterance is short and final text arrives
just after release, the pill keeps that text visible next to the spinner briefly.
Push-to-talk is already wired in `HotkeyService` (press/release) and `AppCoordinator`
(`startListening`/`stopListening`).

Rare ambiguous project/path names can open a one-off native clarification prompt. The
resolved spoken alias is persisted, so this is not part of the normal command input
surface.

## Phases

| # | Phase | Builds | Proves |
|---|---|---|---|
| 1 | [Voice HUD](phase-1-voice-hud.md) | `VoiceHUDController`, transcript→spinner HUD, on-device STT, push-to-talk capture | hold → live transcript → release → transcript + spinner |
| 2 | [Router + registry](phase-2-router-and-registry.md) | `Intent`, `IntentRouter` (deterministic), `ActionHandler`, `HandlerRegistry`, dispatch loop | a spoken phrase routes to a handler |
| 3 | [Executor primitives](phase-3-executor-primitives.md) | `URLSchemeLauncher`, `AppLauncher`, `AppleScriptRunner`, `ShellRunner` + generic handlers (`OpenURL`, `OpenApp`, `BrowserSearch`) | **end-to-end dispatch, sub-second** |
| 4 | [Agent swarm](phase-4-agent-swarm.md) | `SwarmHost` protocol + Ghostty impl, `ProjectResolver`, `AgentSwarmHandler` | "spin up N agents" opens N scoped CLI panes |
| 5 | [Slack reply](phase-5-slack-reply.md) | `SlackReplyHandler` over `PasteService` | realtime "reply to X with Y" pastes a draft |
| 6 | [Artifact window](phase-6-artifact-window.md) | `ArtifactWindow` primitive + `SQLArtifactHandler` (the Prachi flow) | stream output into a floating panel, Run |
| 7 | [LLM router + polish](phase-7-llm-router-and-polish.md) | Tier-1 `LLMRouter` (nano, structured), preconnect, prefetch, latency logging | the long tail routes; budgets met |

Phase 7's router fallback has been pulled forward before phases 5/6 so long-tail spoken
commands can map into the same handler registry while Slack/artifact handlers are still
pending. See the current implementation log for the exact out-of-order status and
remaining polish: [`current-implementation-log.md`](current-implementation-log.md).

## Current implementation order

The build has intentionally diverged from the original linear queue:

| Order built | Phase | Current state |
|---|---|---|
| 1 | Phase 1 — Voice HUD | Built |
| 2 | Phase 2 — Router + registry | Built |
| 3 | Phase 3 — Executor primitives | Built |
| 4 | Phase 4 — Agent swarm | Built on the current branch |
| 5 | Phase 7 — LLM router fallback | Pulled forward on the current branch |
| 6 | Phase 5 — Slack reply | Pending |
| 7 | Phase 6 — Artifact window | Pending |

The pull-forward is narrow: Tier 0 remains the common fast path, and Tier 1 only
classifies missed transcripts into the existing `Intent` shape. It does not replace
handlers or start phases 5/6.

## Conventions for the build

- **Reuse, don't rewrite.** Wire into the kept core (`AppCoordinator`, `FloatingPanel`,
  `HotkeyService`, `PasteService`, `LLMClient`, permission stack).
- **Latency is a requirement.** Honor [`../latency.md`](../latency.md): prewarm,
  optimistic spinner, deterministic fast-path, on-device STT, warm TLS.
- **Never auto-send.** Output handlers paste and stop.
- **Group new code by role** under `Sources/CasprFlowCore/`: `Routing/`, `Handlers/`,
  `Exec/`, `Input/`. Keep handlers thin; put shared mechanics in executors.
- **Keep the checks target green.** Add a small assertion to `CasprFlowChecks` for each
  new pure-logic unit (router matching, slot extraction).
- **Each phase ends with:** `swift build` green, `swift run CasprFlowChecks` passes, and
  the phase's manual acceptance check performed.

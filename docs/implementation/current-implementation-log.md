# Current implementation log

Date: 2026-05-28
Branch: `codex/phase-4-agent-swarm`

## Summary

This branch completes the Phase 4 agent swarm path and pulls the useful part of Phase 7
forward before phases 5 and 6: the LLM router fallback now sits behind the deterministic
router. The reason for the Phase 7 pull-forward is product correctness: short hardcoded
router rules were not enough for natural voice commands, project names, and long-tail
phrases.

The implemented product is now a voice-first macOS dispatcher that can capture speech,
route it through deterministic rules or a strict JSON LLM fallback, and dispatch into
programmatic handlers.

## What changed

- Voice intake now keeps the transcript HUD as the visible command surface. It removed
  app-specific speech bias from default on-device recognition and waits longer for
  one-word partials such as `spin` before finalizing after release.
- `LLMClient` exposes configuration status, uses the repo-local/app-support config path,
  and preconnects to the OpenAI Responses API at startup.
- `TieredIntentRouter` keeps Tier 0 deterministic routing as the zero-network fast path
  and only calls `LLMRouter` when Tier 0 returns `.unknown`.
- `LLMRouter` classifies long-tail commands into the shared `Intent` enum with strict
  JSON structured output. The OpenAI schema uses explicit nullable slot keys because
  strict mode rejects dynamic slot objects.
- The route/dispatch loop logs transcript, routed intent, dispatch result, and latency.
- Phase 4 swarm support adds `SwarmHost`, `GhosttyHost`, `TmuxHost`, `WarpHost`,
  `SwarmSpecBuilder`, `SwarmTaskSplitter`, and `AgentSwarmHandler`.
- Ghostty is the default swarm host. It opens native panes and launches interactive
  Codex. If the user says only `spin up 3 agents`, panes open as plain `codex` sessions
  with no seeded prompt. If the user includes a task, each pane gets a full expanded
  prompt with repo context, agent index, owned slice, constraints, and report-back
  instruction.
- Project resolution is generalized through `ProjectResolver`, `ProjectAliasStore`, and
  `ProjectClarificationService`. Spoken names resolve through learned aliases, exact
  folder matches, and fuzzy candidates under known code roots. Ambiguity opens a native
  clarification prompt and persists the chosen alias.
- Docs were updated so the implementation plan, architecture, decisions, connectors, and
  top-level brief reflect the current voice HUD, Ghostty swarm, learned aliases, and
  pulled-forward LLM router.

## Current phase order

| Phase | Status | Notes |
|---|---|---|
| 1 — Voice HUD | Done | Option+Space push-to-talk, on-device STT, transcript HUD, spinner on release. |
| 2 — Router + registry | Done | `Intent`, deterministic router, handler registry, dispatch loop. |
| 3 — Executor primitives | Done | URL/app/AppleScript/shell executors plus browser search, open URL, open app, guarded shell handlers. |
| 4 — Agent swarm | Done on this branch | Ghostty default host, Codex default tool, task splitting, project resolver, aliases, clarification prompt. |
| 7 — LLM router fallback | Pulled forward on this branch | Tier-1 strict JSON OpenAI nano fallback is built. Remaining latency polish such as speculative prefix prefetch can still be tightened later. |
| 5 — Slack reply | Pending | Should build on `PasteService`; paste draft only, never auto-send. |
| 6 — Artifact window | Pending | Should build the floating artifact primitive and SQL/Prachi reference flow. |

## Current product value

CasprFlow is no longer just a hotkey shell. It is now a working native voice dispatcher
with a real route-to-handler pipeline. The value today is fastest around commands that
map to programmatic actions:

- say a browser search and get the browser opened to results;
- open apps and URLs by voice;
- run guarded shell commands;
- spawn multiple Codex agents in Ghostty panes;
- use short project names after resolution/aliasing;
- rely on the LLM only for command classification misses, not the common path.

This is enough to demonstrate the core product thesis: speak a short command, then the
app dispatches a real programmatic action without a chat box.

## Current capabilities

- Native menu-bar app with Option+Space push-to-talk.
- Center-bottom transcript HUD and processing spinner.
- On-device Apple speech recognition only on the voice path.
- Deterministic Tier-0 router for known fast commands.
- OpenAI `gpt-5.4-nano` Tier-1 fallback for long-tail routing through strict JSON.
- URL/app/browser-search/shell handlers.
- Ghostty-backed agent swarm with native panes and interactive Codex.
- Alternate tmux and Warp swarm hosts kept behind the same protocol.
- Learned project aliases in Application Support.
- Native clarification prompt for ambiguous project names.
- Local config through `casprflow.config.local.json`, environment, or Application
  Support config.
- Headless checks covering router rules, LLM schema/parse behavior, project resolution,
  swarm prompt/command generation, Ghostty AppleScript generation, and executor logic.

## Known gaps

- Speech intake quality still depends on Apple's on-device recognizer. For Wispr/Superwhisper
  quality, the next serious improvement is a persistent in-process local Whisper-class
  recognizer, not a per-utterance CLI process.
- The current HUD is useful for transcript visibility, but it still needs richer error
  and result states for repeated daily use.
- Tier-1 routing is useful but not yet a full planner. It classifies into existing
  handlers; it does not invent new safe actions.
- Phase 5 Slack reply is not built yet.
- Phase 6 artifact window and SQL/Prachi flow are not built yet.
- Project indexing is simple known-root search today. It can improve with a persistent
  repo index, recency ranking, git remote metadata, and alias management UI.
- Latency polish can go further: speculative prefix prefetch, better route timing
  instrumentation, and measuring real hotkey-to-dispatch budgets per handler.

## Validation

- `swift build`
- `swift run CasprFlowChecks`
- `git diff --check`
- Redacted live OpenAI Responses API probe confirmed the fixed strict schema returns
  `200` with `gpt-5.4-nano`.
- Rebuilt the `.app` bundle and reopened the app for manual Option+Space testing.

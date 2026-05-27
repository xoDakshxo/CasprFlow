---
name: casprflow-dispatcher-build
description: Build or modify CasprFlow, the near-realtime macOS voice agent dispatcher. Use when implementing the voice HUD, intent router, action handlers, executor primitives (URL/app/AppleScript/CLI), agent swarm, artifact window, or sequencing work from docs/implementation. Covers scope, build order, and latency guardrails.
---

# CasprFlow Dispatcher Build

## Start here

Read `AGENTS.md`, then the docs in this order before any product/architecture choice:

1. `docs/README.md` — what it is + the three reference flows.
2. `docs/architecture.md` — universal primitives, intent shape, data flow.
3. `docs/decisions.md` — locked choices.
4. `docs/latency.md` — the latency contract.
5. `docs/connectors.md` — the kept core to reuse.
6. `docs/implementation/README.md` — **the execution source of truth.** Work one phase
   at a time, in order.

## What you're building

A voice-first dispatcher: hold **Option+Space** → speak → release → an intent router
classifies the transcript → a handler fires via programmatic methods (URL schemes,
AppleScript, deep links, CLI). No text box. No vision. Sub-second on the common path.

## Core principles (do not violate)

- **Latency is the product.** Deterministic zero-network router fast-path is the default;
  the LLM is a fallback. Prewarm the panel, show the spinner optimistically, use on-device
  STT, warm TLS, route off the main thread.
- **Universal, not app-locked.** Build app-agnostic executor primitives; compose thin
  handlers. New capability = new handler. Keep app-specific logic at the edge.
- **Never auto-send.** Output handlers paste and stop.
- **Reuse the kept core** (`docs/connectors.md`); don't rewrite it.

## Build order (phases)

Follow `docs/implementation/` exactly:

1. Voice HUD (sine-wave → spinner, on-device STT, push-to-talk capture).
2. Intent + deterministic router + handler registry + dispatch loop.
3. Executor primitives + generic handlers (open URL/app, browser search) → first
   end-to-end, sub-second.
4. Agent swarm (`SwarmHost` protocol + Warp impl).
5. Slack realtime reply (via `PasteService`).
6. Artifact window primitive + SQL agent (the Prachi flow).
7. LLM router fallback (nano, structured) + latency polish.

Do not broaden scope until the current phase's acceptance check passes.

## Code layout

New code under `Sources/CasprFlowCore/`, grouped by role: `Input/`, `Routing/`,
`Handlers/`, `Exec/`. Handlers stay thin; shared mechanics live in executors.

## Agent prompts (swarm + SQL phases)

When CasprFlow spawns agents, each prompt must carry the **full intent**: the goal, the
working directory, which slice it owns (agent i of n), constraints, and to report when
done. An unattended agent only knows what its prompt says — make it complete.

## Validation

Each phase ends green:
- `swift build`
- `swift run CasprFlowChecks` (add an assertion for each new pure-logic unit)
- the phase's manual acceptance check (hold-to-talk path actually works)

For docs-only edits: `git status --short` and check for contradictions with the hotkey,
voice-first model, latency rules, and universal-dispatcher principle.

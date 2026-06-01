---
name: casprflow-dispatcher-build
description: Build or modify CasprFlow v3, the ultra-low-latency macOS agentic voice dispatcher. Use when implementing the capability model, FastRouter, Planner, Orchestrator, in-app TaskAgent, computer-use (`control_ui`), executor primitives, agent swarm, artifact window, or sequencing work from docs/implementation. Covers scope, build order (phases 8–16), and latency guardrails.
---

# CasprFlow Dispatcher Build

## Start here

Read `AGENTS.md`, then the docs in this order before any product/architecture choice:

1. `docs/README.md` — what it is + the brain + reference flows.
2. `docs/architecture.md` — plan→capabilities→agent, the three tiers, the `Capability`
   protocol, data flow.
3. `docs/decisions.md` — locked choices (D0 latency governs; D2 revised; D9–D13).
4. `docs/latency.md` — the latency contract.
5. `docs/connectors.md` — the kept core to reuse + what v3 supersedes.
6. `docs/implementation/README.md` — **the execution source of truth.** Work one phase
   at a time, in order.
7. `docs/implementation/CODEX_PLAN.md` — how to work + the PR review checklist.

## What you're building

A voice-first agentic dispatcher: hold **Option+Space** → speak → release →
**FastRouter** (zero network) handles the common case, else the **Planner** emits an
ordered plan of **capability calls** the **Orchestrator** runs. Capabilities span three
tiers — programmatic (URL/app/AppleScript/CLI/paste/swarm), in-app **TaskAgent** loop, and
**computer-use** (`control_ui`, Accessibility-first + vision fallback). No text box.

## Core principles (do not violate)

- **Ultra-low latency governs (D0).** Common path = zero network. The FastRouter must be
  **wide** so the planner stays off it; the planner round-trip is hidden by **speculative
  planning** during speech; computer-use is rare + AX-first. Prewarm panels, optimistic
  spinner, on-device STT, warm TLS, route off-main. Prefer one up-front plan over an
  iterating agent.
- **Universal, not app-locked.** App-agnostic primitives; thin **capabilities** over them.
  New ability = a new `Capability` (+ optional `fastMatch`), never a new enum or plumbing.
  Keep app-specific logic at the edge.
- **Programmatic before vision.** `control_ui` is the last tier; try AX before pixels.
- **Never auto-send.** `.confirm` capabilities gate; outward actions paste-not-send.
- **Reuse the kept core** (`docs/connectors.md`); don't rewrite it.

## Build order (phases 8–16)

Follow `docs/implementation/` exactly, one PR each, strict order:

8. Capability model + registry (migrate executors as capabilities).
9. Wide FastRouter (deterministic → `CapabilityCall`, zero network).
10. Planner (LLM → ordered multi-step `Plan`, strict JSON).
11. Orchestrator + clarify/confirm gates + speculative planning (wire into AppCoordinator).
12. In-app `TaskAgent` loop (`run_task`).
13. `control_ui`: Accessibility driver (AX-first).
14. `control_ui`: vision fallback (computer-use, gated).
15. `ArtifactWindow` + `draft_artifact` + `paste_text` (the Prachi flow).
16. Latency hardening + telemetry + config + polish.

(Phase 1 voice HUD already shipped.) Do not broaden scope until the current phase's
acceptance check passes.

## Code layout

New code under `Sources/CasprFlowCore/`, grouped by role: `Input/`, `Routing/`,
`Capabilities/` (+ `Capabilities/Builtin/`), `Exec/`, `Agent/`, `ControlUI/`.
Capabilities stay thin; shared mechanics live in executors.

## Agent prompts (swarm + TaskAgent)

When CasprFlow spawns a swarm pane or runs a `TaskAgent`, each prompt/goal must carry the
**full task**: the goal, the working context, which slice it owns (agent i of n for
swarm), constraints, and to report when done. An unattended agent only knows what its
prompt says — make it complete.

## Validation

Each phase ends green:
- `swift build`
- `swift run CasprFlowChecks` (add an assertion for each new pure-logic unit)
- the phase's manual acceptance check (hold-to-talk path actually works)

For docs-only edits: `git status --short` and check for contradictions with the hotkey,
voice-first model, latency rules, and universal-dispatcher principle.

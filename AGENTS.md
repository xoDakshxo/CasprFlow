# CasprFlow — Agent Instructions

You (Codex) are building **CasprFlow v3**, an **ultra-low-latency agentic desktop
dispatcher** for macOS. This file is the intent brief. Read it fully, then read the docs
in order and work the phases in `docs/implementation/` one PR at a time. The reviewer
(Claude, on the user's behalf) grades each PR against
`docs/implementation/CODEX_PLAN.md` — self-check against it before opening a PR.

## What CasprFlow is (internalize this)

Raycast + Wispr Flow, but it **interprets an arbitrary spoken task and does it for you in
realtime**. Hold **Option+Space**, speak, release. CasprFlow figures out *which mechanism*
does the job and runs it. There is **no command text box**: voice is the input.

The v3 brain replaces v2's brittle classify-into-fixed-enum router:

```
voice → FastRouter (zero network) ──hit──→ run one capability
            │ miss
            ▼
        Planner (LLM) → ordered capability calls → Orchestrator executes
```

Every task resolves to the **cheapest of three tiers**:
1. **Programmatic** — URL schemes, AppleScript, deep links, CLI, paste, swarm. First.
2. **Agentic** — an in-app `TaskAgent` loop over capabilities, for multi-step tasks.
3. **Computer-use** (`control_ui`) — Accessibility-first, vision fallback. Last resort.

A **Capability** is the single extension point: adding ability = registering a capability
(+ optional deterministic `fastMatch`), never a new enum case or bespoke plumbing.

## The two non-negotiables

1. **Ultra-low latency is the governing constraint (D0).** It overrides feature scope.
   The common path touches **zero network**; the FastRouter must be **wide** so the
   planner stays off it; the planner round-trip is **hidden by speculative planning**
   during speech; computer-use is **rare by construction** and AX-first. If a capability
   can't hit its tier budget, change the approach — not the budget. See `docs/latency.md`.
2. **Universal by design (D2b).** A general dispatcher, not a launcher for a fixed app
   list. Build app-agnostic primitives; compose thin capabilities over them. Never
   hardcode app-specific knowledge into the core — keep it at the edge (a capability, a
   config entry).

## Read these, in order

1. `docs/README.md` — what it is, the brain, the reference flows.
2. `docs/architecture.md` — the plan→capabilities→agent model, the three tiers, the
   `Capability` protocol, data flow.
3. `docs/decisions.md` — locked choices. D0 (latency) governs; D2 revised (computer-use is
   the gated last tier); D9–D13 are the v3 additions.
4. `docs/latency.md` — **the contract every phase is graded against.**
5. `docs/connectors.md` — the kept core to reuse (and what v3 supersedes).
6. `docs/implementation/README.md` — the phase queue (8–16). **Execution source of truth.**
7. `docs/implementation/CODEX_PLAN.md` — how to work + the PR review checklist.

## The codebase right now

The v2 phases shipped voice input, a deterministic+LLM intent router, executor
primitives, generic handlers, and the Ghostty agent swarm. v3 **keeps and reuses** the
native shell, voice, executors, swarm, `LLMClient`, and the permission stack — and
**replaces the intent layer**: the fixed `IntentKind` enum, `DeterministicRouter`,
`LLMRouter`/`TieredIntentRouter`, and `ActionHandler`/`HandlerRegistry` give way to the
capability model + FastRouter + Planner + Orchestrator. `docs/connectors.md` lists exactly
what is kept, what is superseded, and when each superseded file is deleted (in the phase
that replaces it — one brain in the tree at a time).

## Working rules

- **Stack:** Swift, SwiftUI, AppKit, SwiftPM. Native menu-bar/background app. No Electron.
- **Reuse the kept core**; wire into it. Group new code by role under
  `Sources/CasprFlowCore/`: `Input/`, `Routing/`, `Capabilities/`, `Exec/`, `Agent/`,
  `ControlUI/`.
- **One phase per PR**, titled `[v3][Phase N] …`. Don't jump ahead or broaden scope.
- **Latency is acceptance.** Hit the tier budget; log/measure where you touch the hot
  path. Widen FastRouter rather than letting commands fall to the planner. Prefer a single
  up-front plan over an iterating agent. AX before vision, always.
- **Keep it green.** Each phase ends with `swift build` passing and
  `swift run CasprFlowChecks` passing. Add a `CasprFlowChecks` assertion for **every** new
  pure-logic unit (matchers, schema builders, plan parsers, AX selectors, coordinate
  math). Pure logic must be testable with **no app and no network** — inject stubs
  (`LLMCompleting`, `ComputerUseModel`, service spies).
- **Never auto-send.** Outward/irreversible capabilities are `.confirm` and paste-not-send;
  destructive shell is confirm, not auto-run.
- **When you spawn a swarm or an agent, give it the FULL task.** Each `spawn_swarm` pane
  prompt and each `run_task` goal must carry complete framing — the goal, the working
  context, which slice it owns, and to report when done. Vague prompts produce vague work.
- **Keep docs aligned.** If you change a seam, hotkey, or interface, update the doc that
  would otherwise contradict it (and this file).

## Config

`casprflow.config.local.json` (git-ignored): `openai_api_key`, `openai_model`
(default `gpt-5.4-nano`), `openai_reasoning_effort`, plus v3 additions `anthropic_api_key`,
`computer_use_model`, `computer_use_enabled`, `planner_timeout_ms`, and the existing
`user_name` / `user_style`. `LLMConfig.load()` reads env → this file → app-support.

## Repo-local skills

- `.codex/skills/casprflow-dispatcher-build/SKILL.md` — the build sequence + guardrails.
- `.codex/skills/casprflow-macos-automation/SKILL.md` — hotkey, HUD, paste, permissions,
  programmatic execution + AX/`CGEvent` patterns for `control_ui`.
- `.codex/skills/casprflow-product-docs/SKILL.md` — keeping docs aligned.

If the runtime doesn't auto-discover them, read the `SKILL.md` files manually first.

# CasprFlow v3 — Agentic Realtime Dispatcher

CasprFlow is a near-realtime desktop agent for macOS. Think Raycast + Wispr Flow, but
instead of just launching apps it **interprets an arbitrary spoken task and does it on
your behalf** — dispatching to programmatic actions, an in-app agent loop, or (last
resort) computer-use.

You **hold** a global hotkey (**Option + Space**) and speak. A small Wispr-style
transcript pill appears center-bottom and updates while you talk; on release it
transitions into the CasprFlow spinner while the orchestrator runs. There is **no command
text box**; voice is the input.

## The brain (v3)

```
voice → FastRouter (zero network) ──hit──→ run one capability
            │ miss
            ▼
        Planner (LLM) → ordered capability calls → Orchestrator executes
```

Every task resolves to the **cheapest of three tiers**:

1. **Programmatic** — URL schemes, AppleScript, deep links, CLI, paste, swarm. Tried
   first, ~instant.
2. **Agentic** — an in-app `TaskAgent` loop that calls capabilities until the goal is met,
   for multi-step tasks.
3. **Computer-use** — `control_ui`: Accessibility-first, vision fallback. The gated last
   resort for apps with no programmatic path.

A **Capability** is the single extension point: adding ability = adding a capability, not
new plumbing. It is a universal dispatcher, not a launcher for a fixed app list.

## The non-negotiable: latency

The product lives or dies on **ultra-low latency** (decision D0). The common path touches
**zero network**; the planner round-trip is hidden by **speculative planning** during
speech; computer-use is rare by construction. See [`latency.md`](latency.md).

## Reference flows (examples, not the scope)

1. **Instant search** — "get me the best restaurants from Google" → browser opens,
   sub-second (tier 1).
2. **Agent swarm** — "spin up 3 agents on casprflow for UI docs, tests, and cleanup" →
   Ghostty opens with 3 native Codex panes (tier 1, out-of-process coding agents).
3. **Realtime reply** — "reply to Prachi that we'll ship Friday" → draft pasted into the
   composer, **never auto-sent** (tier 1, confirm gate).
4. **Draft + run** — "get this doc ready for Prachi" → a skill-loaded agent streams a SQL
   query into a floating artifact window; user clicks Run (tiers 1–2, artifact window).
5. **Do it for me** — an open-ended multi-step desktop task → planner routes to the
   in-app `TaskAgent`, which uses programmatic capabilities and, only if needed,
   `control_ui` (tiers 2–3).

## Status

v3 redesign. v2's classify-into-fixed-enum router + thin handlers is being replaced by the
agentic orchestrator (capability model → wide FastRouter → planner → orchestrator →
task agent → computer-use). Kept and reused: the native shell, voice input, executors,
the Ghostty swarm, `LLMClient`, the permission stack. The build is sequenced in
[`implementation/README.md`](implementation/README.md), phases 8–16.

## How to run

```bash
swift build                 # build the menu-bar app + checks
swift run CasprFlow         # launch (menu-bar item; hold Option+Space to talk)
swift run CasprFlowChecks   # headless smoke checks (offline; stubs for model/screen)
```

First launch prompts for Accessibility; the voice path adds Microphone + Speech
Recognition; `control_ui` makes Accessibility + Screen Recording load-bearing. The
menu-bar item walks you through granting them and preserves the drag-the-app-into-Settings
flow.

## Doc map

- [`architecture.md`](architecture.md) — the plan→capabilities→agent model, three tiers,
  the capability protocol, data flow.
- [`decisions.md`](decisions.md) — locked choices (D0 latency governs; D2 revised; D9–D13).
- [`latency.md`](latency.md) — the latency contract + tactics (FastRouter moat,
  speculative planning).
- [`connectors.md`](connectors.md) — the kept core: every file, what it does, how to use it.
- [`implementation/README.md`](implementation/README.md) — the phase queue (8–16).
- [`implementation/CODEX_PLAN.md`](implementation/CODEX_PLAN.md) — how Codex works + the
  PR review checklist.

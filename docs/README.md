# CasprFlow v2 — Realtime Agent Dispatcher

CasprFlow is a near-realtime desktop agent dispatcher for macOS. Think Raycast +
Wispr Flow, but instead of just launching apps it **dispatches to agents and
executes programmatic actions fast**.

You **hold** a global hotkey (**Option + Space**) and speak. A small Wispr-style
sine-wave HUD appears center-bottom while you talk; on release it morphs into the
CasprFlow spinner while an intent router classifies the command and a handler fires
immediately using **programmatic methods** (URL schemes, AppleScript, CLI, deep links)
— not vision-based computer use. There is **no text box**; voice is the input. Sub-second
dispatch on the common path.

It is a **universal dispatcher**, not a launcher for a fixed set of apps. A small set of
app-agnostic executor primitives (open any URL/app, run any AppleScript/CLI, paste into
any app, stream into a floating artifact window, spawn an agent swarm) is composed into
thin handlers. The flows below are reference handlers that prove the primitives — not
the ceiling.

## The non-negotiable: latency

The product lives or dies on **extreme low latency**. Every design choice bends
toward sub-second dispatch. The common path must touch zero network and zero
allocation. See [`latency.md`](latency.md) for the contract and the tactics.

## The three demo flows

1. **Instant browser search** — "get me the best restaurants from Google" → the
   browser opens with results, sub-second.
2. **Agent swarm** — "spin up 5 agents and refactor the UI docs" → a terminal
   opens with 5 panes, each running a Claude Code or Codex CLI instance.
3. **Realtime Slack reply** — Slack notification → hotkey → "reply to Prachi that
   we'll ship Friday" → the draft is pasted into the Slack composer in near real
   time (never auto-sent).

## Status

This repo is at the **post-pivot skeleton** stage:

- The retired "knowledge fast replies" reply-capsule product has been stripped.
- The native shell + connectors are kept and clean (see [`connectors.md`](connectors.md)).
- The dispatcher (command bar, intent router, action handlers, voice, swarm) is
  **not built yet** — it is specified phase-by-phase in
  [`implementation/`](implementation/README.md) for a Codex-driven build.

## How to run

```bash
swift build           # build the menu-bar app + checks
swift run CasprFlow   # launch (menu-bar item; hold Option+Space to talk)
swift run CasprFlowChecks   # headless smoke checks
```

First launch prompts for Accessibility (needed for synthetic paste); the voice phase
adds Microphone + Speech Recognition prompts. The menu-bar item walks you through
granting Accessibility — it preserves the drag-the-app-into-Settings flow. See
[`connectors.md`](connectors.md#permissions-kept-whole--the-drag-into-settings-flow).

## Doc map

- [`architecture.md`](architecture.md) — layers, data flow, latency budget.
- [`connectors.md`](connectors.md) — the kept core: every file, what it does, how to use it.
- [`latency.md`](latency.md) — the latency contract + tactics.
- [`decisions.md`](decisions.md) — locked technical choices and why.
- [`implementation/`](implementation/README.md) — the phased build plan for Codex.

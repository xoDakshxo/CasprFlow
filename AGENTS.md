# CasprFlow — Agent Instructions

You (Codex) are building **CasprFlow v2**, a near-realtime desktop **agent dispatcher**
for macOS. This file is the intent brief. Read it fully before writing code, then work
the phases in `docs/implementation/`.

## What CasprFlow is (the intent — internalize this)

Raycast + Wispr Flow, but it **dispatches to agents and executes programmatic actions
fast** instead of just launching apps. The user **holds Option+Space**, speaks a
command, and a handler fires immediately via **programmatic methods** (URL schemes,
AppleScript, deep links, CLI) — **never** vision/computer-use. There is **no text box**:
voice is the only input.

The interaction:
1. Hold **Option + Space** (push-to-talk).
2. A small **Wispr-style transcript HUD** appears center-bottom and updates with your words.
3. You speak; on-device speech recognition streams the transcript.
4. You **release**; the pill **transitions into the existing CasprFlow spinner** while
   short-utterance text can still finalize, then the intent router classifies and a
   handler dispatches.
5. The action happens. Outward-facing actions (sending) are **never auto-performed** —
   we paste a draft and let the user send.

Three reference flows (these are **examples that prove the primitives, not the scope**):
- *"Get me the best restaurants from Google"* → browser opens with results, instantly.
- *"Spin up 5 agents and refactor the UI docs"* → a terminal opens with 5 panes, each
  running a headless Claude Code or Codex CLI on the task.
- *"Get this doc ready for Prachi"* → a skill-loaded SQL agent streams a query into a
  floating always-on-top artifact window; the user clicks Run; it executes against
  ClickHouse and confirms.

## Two non-negotiables

1. **Latency is the product.** Sub-second dispatch on the common path. Every choice
   bends toward it: prewarmed window, optimistic spinner, deterministic zero-network
   router fast-path, on-device STT, warm TLS, speculative prefetch. If a feature can't
   hit its budget, change the approach — not the budget. See `docs/latency.md`.
2. **Universal by design.** CasprFlow is a *general dispatcher*, not a launcher for a
   fixed app list. Build **app-agnostic executor primitives** (open any URL/app, run any
   AppleScript/CLI, paste into any app, stream into an artifact window, spawn a swarm)
   and compose **thin handlers** over them. Adding a capability = adding a handler, not
   new plumbing. **Never hardcode app-specific knowledge into the core** — keep it at the
   edge (a handler or config). See `docs/decisions.md` (D2b).

## Read these, in order

1. `docs/README.md` — what it is, the three flows, how to run.
2. `docs/architecture.md` — layers, the universal-primitives model, intent shape, data flow.
3. `docs/decisions.md` — locked choices (voice-first, two-tier router, OpenAI-nano
   fallback, swappable swarm host, never-auto-send, universal-by-design).
4. `docs/latency.md` — the latency contract and tactics.
5. `docs/connectors.md` — the kept core: every reusable file and how to wire into it.
6. `docs/implementation/README.md` — the phase queue. **This is the execution source of
   truth.** Work one phase at a time.

## The codebase right now

The old "knowledge fast replies" reply-capsule product was **scrapped**. The native
shell + connectors are kept, and the phased dispatcher build is underway:
- Menu-bar app launches; **Option+Space is push-to-talk** (press/release wired in
  `HotkeyService` + `AppCoordinator`); the center-bottom voice HUD streams on-device
  transcript text and hands the final transcript into the dispatcher.
- Phase 2 adds the deterministic router, intent model, handler protocol/registry, and
  route→dispatch loop with a logging stub until real handlers arrive in phase 3.
- Phase 3 adds the universal URL/app/AppleScript/shell executors plus browser-search,
  open-URL, open-app, and guarded shell handlers for first end-to-end dispatch.
- Kept connectors: `HotkeyService`, `FloatingPanel` (HUD/artifact shell), `PasteService`,
  `CasprFlowLogo`/`CasprFlowLogoMark` (spinner), `LLMClient` (OpenAI text client), the
  full permission stack (Accessibility + Screen Recording, **including the
  drag-the-app-into-Settings flow** — keep it), `StatusItemController`.
- Everything reply/chip/capture-specific was deleted.

`docs/connectors.md` maps each kept file. **Reuse these — do not rewrite them.**

## Working rules

- **Stack:** Swift, SwiftUI, AppKit, SwiftPM. Native, menu-bar/background app. No Electron.
- **Reuse the kept core**; wire new code into it. Group new code by role under
  `Sources/CasprFlowCore/`: `Input/`, `Routing/`, `Handlers/`, `Exec/`.
- **One phase at a time.** Complete the phase in `docs/implementation/`, meet its
  acceptance check, then stop. Don't jump ahead or broaden scope.
- **Keep it green.** Each phase ends with `swift build` passing and
  `swift run CasprFlowChecks` passing. Add a small assertion to `CasprFlowChecks` for
  each new piece of pure logic (router rules, slot extraction, URL builders, swarm spec).
- **Never auto-send.** Output handlers paste and stop.
- **Latency-aware always.** Don't make the LLM the default path; don't reallocate the
  panel per invoke; route off the main thread; show the spinner optimistically.
- **When you spawn agents (swarm phase), give them the FULL intent.** Each agent prompt
  must carry the complete task + framing so a fresh, unattended agent knows exactly what
  to do: the goal, the working directory, which slice it owns (agent i of n), and to
  report when done. Vague prompts produce vague work.
- **Keep docs aligned.** If you change scope, hotkey, or an interface, update the docs
  that would otherwise contradict it (and this file).

## Config

`casprflow.config.local.json` (git-ignored) holds `openai_api_key`, `openai_model`
(default `gpt-5.4-nano`), `openai_reasoning_effort`, plus `user_name` / `user_style`
used when drafting replies as the user. `LLMConfig.load()` reads env → this file →
app-support.

## Repo-local skills

- `.codex/skills/casprflow-dispatcher-build/SKILL.md` — the build sequence + guardrails.
- `.codex/skills/casprflow-macos-automation/SKILL.md` — hotkey, HUD, paste, permissions,
  programmatic execution patterns.
- `.codex/skills/casprflow-product-docs/SKILL.md` — keeping docs aligned.

If the runtime doesn't auto-discover them, read the `SKILL.md` files manually first.

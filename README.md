# CasprFlow

Near-realtime desktop **agent dispatcher** for macOS. Hold a hotkey, speak, and it fires:

```text
hold Option + Space  ->  speak  ->  release  ->  intent router  ->  programmatic action
```

Raycast + Wispr Flow, but instead of just launching apps it **dispatches to agents and
executes programmatic actions fast** (URL schemes, AppleScript, deep links, CLI) — never
vision-based computer use. There is **no text box**: a small Wispr-style transcript pill
appears center-bottom while you talk, then transitions into the CasprFlow spinner while
late short-utterance text can still surface. The command is then classified and
dispatched. Sub-second on the common path.

It's a **universal dispatcher**, not a launcher for a fixed set of apps. App-agnostic
executor primitives compose into thin handlers. Reference flows:

- "Get me the best restaurants from Google" → browser opens with results, instantly.
- "Spin up 5 agents and refactor the UI docs" → a terminal opens with 5 headless
  Claude Code / Codex panes.
- "Get this doc ready for Prachi" → a SQL agent streams a query into a floating
  artifact window; click Run; it executes against ClickHouse.

## Status

The previous reply-capsule product was scrapped. The native shell + connectors are kept
and building green. Voice input, the deterministic intent router/handler registry, and
the first generic executor primitives/handlers are built; specialized handlers continue
in the remaining implementation phases.

## Docs

- `AGENTS.md` — the intent brief + working rules for agents.
- `docs/README.md` — overview + the three flows.
- `docs/architecture.md` — layers, universal primitives, intent shape.
- `docs/decisions.md` — locked choices. `docs/latency.md` — the latency contract.
- `docs/connectors.md` — the kept native core. `docs/implementation/` — the phase queue.

## Build

```sh
swift build                 # build the menu-bar app + checks
swift run CasprFlow         # launch (menu-bar item; hold Option+Space to talk)
swift run CasprFlowChecks   # headless smoke checks
# or: make build / make run
```

## Permissions

- **Accessibility** — synthetic key events / paste.
- **Microphone** + **Speech Recognition** — on-device voice input (added with the voice
  phase).
- Granted in `System Settings > Privacy & Security`; the menu-bar helper guides you and
  preserves the drag-the-app-into-Settings flow. Re-grant after rebuilds that re-sign.

## Guardrails

Fixed **Option + Space** (push-to-talk). OpenAI Responses `gpt-5.4-nano` for the router
fallback only; the deterministic fast-path is the default. Latency is the product. Paste,
never auto-send. Universal by design — keep app-specifics at the edge. Scope changes go
through the docs first.

## Visual assets

- Logo SVG variants in `Assets/logo/`; rendered natively (`CasprFlowLogo`) for the menu
  bar and the HUD spinner. Light UI uses the black mark, dark UI the white mark.
- The looping fill animation (`CasprFlowLogoMark`) is the processing spinner.

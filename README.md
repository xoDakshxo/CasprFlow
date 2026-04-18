# CasprFlow

Native macOS reply layer. One narrow loop:

```text
Option + Space  ->  ScreenContextBundle  ->  3 intent chips  ->  pick one  ->  full expansion  ->  paste
```

CasprFlow understands the screen by the time you press the hotkey. It does not show three full drafts. It shows three short moves you can pick in under a second, then expands the picked move into a full reply tailored to the current app (Slack vs Codex vs iMessage vs Mail).

## Documents

- `docs/CasprFlow-Concept-v1.md` — original wedge.
- `docs/CasprFlow-Product-Model-v1.md` — interaction model (chips → expansion).
- `docs/CasprFlow-Tech-Spec-v1.md` — technical surface and bundle shape.
- `docs/phases/README.md` — phase queue.

## Status

Branch: `codex/phase-5-openai-intent-chips`

| Phase | Status |
|---|---|
| 0 Intake | Done |
| 1 Walking skeleton | Done |
| 2 Selected text + rich AX context | Done |
| 3 Stub reply capsule + paste | Done |
| 4 Structured Context Bundle | Done |
| 5 Three intent chips | Done |
| 6 Local learning | Pending |
| 7 Hardening + demo | Pending |

Phases 4 and 5 together replace the previous "Phase 4 generation" + "Phase 6 Regenerate" plan. Picking a chip is the regeneration loop.

## Build

```sh
make build      # SwiftPM build, signed local app bundle
make test       # SwiftPM unit tests + CasprFlowChecks
make run        # launch the menu-bar app
```

## Permissions

- Accessibility (hotkey, AX, paste).
- Screen Recording (active-window screenshot for OpenAI vision context and local OCR diagnostics).

Granted in `System Settings > Privacy & Security`. Re-grant after rebuilds that re-sign the bundle.

## MVP Guardrails

Fixed `Option + Space`. OpenAI Responses API with `gpt-5.4-nano` by default. No auto-send. No editor overlay. No accounts, sync, dashboards, embeddings, fine-tuning, analytics, or send detection. Scope changes go through the docs first.

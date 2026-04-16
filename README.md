# CasprFlow

CasprFlow is a native macOS reply layer for one narrow MVP loop:

```text
highlight message -> Option + Space -> tiny reply capsule -> edit or regenerate -> paste -> learn locally
```

The day-one product is intentionally small. It is a menu-bar/background Mac app with selection-first context capture, one generated reply, an editable capsule, `Command + R` regeneration, paste-only delivery, Gemini generation, and local JSON learning.

## Current Checkpoint

Current branch:

```text
codex/phasewise-mvp-implementation
```

Current status:

```text
Phase 0: Passed
Phase 1: Passed
Phase 2: Complete
Next: Phase 3
```

This checkpoint proves the planning path, native app shell, fixed hotkey, placeholder capsule, Accessibility permission path, selected-text capture, compact product capsule preview, and rich debug context display.

## This PR

This PR checkpoints Phases 0 through 2 into `main`.

Progress included:

- Added the SwiftPM native macOS app scaffold.
- Added a menu-bar/background app entrypoint.
- Added fixed `Option + Space` Carbon hotkey registration.
- Added a tiny borderless reply capsule controller.
- Added Accessibility permission checks and menu state.
- Added selected-text capture through Accessibility APIs with range fallback and clipboard fallback.
- Added rich screen context capture for focused app, windows, element metadata, surrounding text, full element value, and visible UI tree.
- Split Phase 2 UI into two windows: a compact product capsule preview and the rough debug context inspector.
- Added command-line build and check targets through `make build` and `make test`.
- Added app bundle creation with stable signing behavior for TCC continuity.
- Added Phase 0, Phase 1, and Phase 2 reports under `docs/phase-reports/`.
- Updated phase docs and repo-local automation guidance to match the current capture approach.

Validation for this checkpoint:

- `make build`
- `make test`

## Next PR

Next PR should execute:

```text
docs/phases/phase-3-stub-reply-capsule-and-paste.md
```

Goal:

```text
selected text -> stub reply -> edit in capsule -> paste into active app
```

Expected work:

- Replace the Phase 2 product preview text with a deterministic stub reply.
- Keep the capsule draft editable and route it into the paste flow.
- Add keyboard handling for `Enter`, `Command + R`, and `Escape`.
- Restore focus to the previous app before paste.
- Paste the final capsule text into the active field.
- Restore clipboard best-effort after paste.
- Write `docs/phase-reports/phase-3-stub-reply-capsule-and-paste.md`.

## Remaining MVP PR Queue

Use one phase per PR unless the scope is explicitly changed.

| PR | Phase | Goal |
| --- | --- | --- |
| Current | Phases 0-2 | Planning, app shell, hotkey, selected text, rich context |
| Next | Phase 3 | Stub reply capsule and paste into active app |
| Later | Phase 4 | Gemini generation service |
| Later | Phase 5 | Local learning store and visible learned label |
| Later | Phase 6 | Regenerate from edited draft with `Command + R` |
| Later | Phase 7 | MVP hardening and demo candidate |

## MVP Guardrails

Keep the MVP narrow:

- Native macOS app.
- Menu-bar/background lifecycle.
- Fixed `Option + Space` hotkey.
- Selection-first context capture.
- Tiny reply capsule.
- Gemini generation.
- One generated reply.
- Editable draft inside the capsule.
- `Command + R` regenerate from edit.
- `Enter` paste.
- No auto-send.
- Local JSON learning.
- One visible learned label.

Do not add browser extensions, mobile, accounts, sync, app integrations, dashboards, embeddings, fine-tuning, analytics, or send detection unless the MVP scope is explicitly expanded.

## Development

Build:

```sh
make build
```

Run checks:

```sh
make test
```

Run the app:

```sh
make run
```

For phase work, follow `docs/phases/README.md`: complete one phase, run the phase checks, write the phase report, and stop.

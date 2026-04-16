# CasprFlow

CasprFlow is a native macOS reply layer for one narrow MVP loop:

```text
focus reply field -> Option + Space -> tiny reply capsule -> edit or regenerate -> paste -> learn locally
```

The day-one product is intentionally small. It is a menu-bar/background Mac app with automatic current-window context, optional selection as a precision signal, one generated reply, an editable capsule, `Command + R` regeneration, paste-only delivery, Gemini generation, and local JSON learning.

## Current Checkpoint

Current branch:

```text
codex/phase-3-stub-reply-capsule-paste
```

Current status:

```text
Phase 0: Passed
Phase 1: Passed
Phase 2: Complete
Phase 3: Implemented, manual smoke pending
Next: Phase 4 after Phase 3 smoke passes
```

This checkpoint proves the planning path, native app shell, fixed hotkey, placeholder capsule, Accessibility permission path, selected-text capture, compact product capsule, separate debug context display, deterministic stub replies, draft editing, stub regeneration, and the paste service path.
The current intermediary work also adds AX-first prompt context so selection is no longer required for the debug/product capsule path.

## This Phase

This branch implements Phase 3 on top of the Phase 2 product preview/debug split.

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
- Added a deterministic non-AI stub reply generator.
- Added prompt-ready AX context with capture mode, confidence, candidate count, and chrome pruning.
- Made selected text optional instead of mandatory for opening the product capsule.
- Added product capsule keyboard handling for `Enter`, `Command + R`, and `Escape`.
- Added a paste service for pasteboard backup, focus restore, synthetic paste, and pasteboard restore.
- Added `docs/phase-reports/phase-3-stub-reply-capsule-and-paste.md`.

Validation for this branch:

- `make build`
- `make test`

Manual smoke still required:

- Grant Accessibility again if macOS asks after the re-signed build.
- Run the Phase 3 Notes smoke test from `docs/phase-reports/phase-3-stub-reply-capsule-and-paste.md` with the cursor in the reply field and no selected text.

## Next PR

Next implementation should continue the automatic context intermediary plan before final Gemini polish:

```text
docs/CasprFlow-Automatic-Screen-Context-Phase-Plan-v1.md
```

Goal:

```text
AX prompt context -> local OCR assist -> compact Gemini context -> one fast reply
```

Expected work:

- Add hotkey-triggered active-window OCR only when AX confidence is weak.
- Merge OCR candidates into prompt context.
- Keep raw AX/OCR dumps in the debug inspector.
- Send only compact context to Gemini by default.
- Keep screenshot-to-Gemini as a later low-confidence fallback, not default behavior.

## Remaining MVP PR Queue

Use one phase per PR unless the scope is explicitly changed.

| PR | Phase | Goal |
| --- | --- | --- |
| Merged | Phases 0-2 base | Planning, app shell, hotkey, selected text, rich context |
| Pending | Phase 2 addition | Product capsule preview and separate debug inspector |
| Current | Phase 3/intermediary | Stub capsule, paste path, AX-first automatic prompt context |
| Next | Context assist | Local OCR assist and compact prompt fusion |
| Later | Phase 4 | Gemini generation service |
| Later | Phase 5 | Local learning store and visible learned label |
| Later | Phase 6 | Regenerate from edited draft with `Command + R` |
| Later | Phase 7 | MVP hardening and demo candidate |

## MVP Guardrails

Keep the MVP narrow:

- Native macOS app.
- Menu-bar/background lifecycle.
- Fixed `Option + Space` hotkey.
- Automatic current-window context, with selection as optional precision input.
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

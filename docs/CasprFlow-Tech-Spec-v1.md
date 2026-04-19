# CasprFlow Tech Spec

Last updated for the post–Phase 3 refocus on a structured context bundle and three intent chips.

## Platform

- Native macOS, target macOS 14+.
- Menu-bar/background app (`LSUIElement`).
- No browser extension, no mobile app, no Electron.

## Language and UI

- Swift + SwiftUI for the small visible UI.
- AppKit for menu-bar lifecycle, `NSPanel`, focus, paste, accessibility.

## App Shell

- `NSStatusItem` menu-bar agent.
- Fixed global hotkey: `Option + Space`.
- Minimal menu: Enable / permission helpers / Clear learning / Quit.
- No hotkey picker. No settings screen.

## Context Capture

CasprFlow gathers a single structured context bundle on every hotkey press. Selection is optional; the happy path does not require it.

Pipeline:

1. Active app, bundle id, window title, focused element via Accessibility (AX).
2. AX tree walk for visible text, focused field value, surrounding text.
3. Active-window screenshot capture, cropped to interaction regions:
   - focused-field region (extends upward for chat history)
   - cursor-near region
   - visible-window fallback
   - full window fallback
4. Apple Vision OCR (`accurate`, language correction) on each crop.
5. OCR lines grouped into message-like blocks by spatial proximity.
6. Surface kind detection from bundle id + role (chat / code / email / docs / casual / other).
7. All of the above fused into a `ScreenContextBundle` JSON-shaped struct.

Phase 5 attaches one compressed interaction crop to OpenAI as image input, alongside AX context. OCR remains local diagnostic context and is not sent in generation prompts.

## ScreenContextBundle Shape

The bundle is the single source of truth for downstream consumers (UI, intent chips, generation, learning).

```text
surface:        kind, app, bundleId, windowTitle, isInputFocused
focused:        role, subrole, value, fieldKind (chat/code/email/note/url/other)
selection:      optional cleaned selected text
recent:         ordered message-like blocks (most recent first), each with text + source
ambient:        non-focal context (toolbar, headers, sidebar) kept separate
prompt:         compact text projection for prompts (token-budgeted)
debug:          raw AX candidates, raw OCR candidates, screenshots metadata
confidence:     0.0–1.0, derived signal quality score
```

The bundle is `Codable` so it can be serialized for prompts, debug dumps, and learning.

## Reply UI

Two-stage reply, not a generic editor:

1. **Three intent chips**: short, action-level moves (1–3 words each) chosen for the current surface. The user picks one with a click or `1`/`2`/`3`.
2. **Expansion**: the picked chip is expanded into a full draft tailored to the surface.

States:

- `Drafting…` while the bundle is being assembled.
- `Pick a move` once chips are ready.
- `Editing` after expansion, with the standard capsule controls.
- `Error` for permission or API issues.

Keyboard:

- `1`/`2`/`3`: pick chip.
- `Enter`: paste current draft.
- `Cmd+R`: regenerate the current chip's expansion (uses the user's edit if any).
- `Tab`: cycle to next chip.
- `Esc`: close.

## Generation

- OpenAI Responses API over `URLSession`.
- Default model: `gpt-5.4-nano`.
- Two prompt shapes:
  1. **Chip prompt**: bundle in, returns three short intent labels.
  2. **Expansion prompt**: bundle + chip + (optional) edited draft, returns one final reply.
- API key from `OPENAI_API_KEY`, root `casprflow.config.local.json`, or Application Support config (`openai_api_key`).
- Optional model override from `OPENAI_MODEL`, root `casprflow.config.local.json`, or Application Support config (`openai_model`).
- Attach one compressed screenshot crop as image input with AX context; do not send OCR text in generation prompts.
- Default reasoning effort is `low` for latency; stale `minimal` config values are normalized to `low`.
- Mock mode for tests.

## Surface-Specific Realization

The same bundle produces different chip vocabularies and expansion styles per surface kind:

- **chat**: coordination moves (Take it, Push timing, Ask context).
- **code**: execution moves (Implement, Inspect first, Plan steps).
- **casual**: human moves (Yes, Soft no, Not sure).
- **email**: structured moves (Confirm, Defer, Decline).
- **other**: generic (Confirm, Clarify, Decline).

Realization is rule-based first; learned overrides come later.

## Learning

- Local JSON: `~/Library/Application Support/CasprFlow/preferences.json`.
- Stored per event:
  - bundle summary
  - chip picked
  - generated expansion
  - final pasted text
  - inferred style signals (shorter, warmer, no_emojis, etc.)
- No DB, no embeddings, no fine-tuning.

## Packaging

- SwiftPM build only.
- Local app bundle via `Scripts/`.
- No notarization, installer, or auto-update for the MVP.

## Source Reuse

- `bwarzecha/Axii` (Apache-2.0): menu-bar shell, hotkey, paste, permission patterns.
- `bytefer/macos-vision-ocr` (MIT): Vision OCR request/output shape.
- `zats/permiso` (license not present in inspected checkout): reference for drag/drop Accessibility and Screen Recording permission guidance; resolve license before copying source.
- Preserve license headers; add `THIRD_PARTY_NOTICES.md` before public distribution.

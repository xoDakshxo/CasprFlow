# CasprFlow Tech Spec
### Day-one MVP technical choices

## Platform

- Native macOS app.
- macOS 14+ target for the MVP.
- Menu-bar/background app.
- No browser extension.
- No Electron.
- No mobile app.

## Language and UI

- Swift.
- SwiftUI for the small visible UI.
- AppKit for menu-bar app lifecycle, `NSPanel`, focus control, paste automation, and accessibility checks.

## App shell

- `NSStatusItem` menu-bar app.
- `LSUIElement` agent-style app.
- Fixed global hotkey for the MVP.
- Minimal menu:
  - Enable CasprFlow.
  - Clear learning.
  - Quit.

## Hotkey

- Use the HotKey-style Carbon wrapper already proven in the source-reuse candidate.
- Fixed default hotkey: `Option + Space`.
- No hotkey picker in the MVP.
- If registration fails, show a simple error.

## Context capture

- Copy-based selected-text capture.
- `NSPasteboard` for clipboard read/write.
- Synthetic `Command + C` for selected context.
- Clipboard restore best-effort only.

## Reply UI

- Ultra-minimal floating reply capsule.
- Borderless `NSPanel`.
- One editable draft field.
- No large editor overlay.
- No settings panel.
- Keyboard-first controls:
  - `Enter` paste.
  - `Command + R` regenerate from the current edited draft.
  - `Escape` cancel.

## Generation

- OpenAI API over `URLSession`.
- One text-generation request per draft.
- One text-generation request per regeneration.
- Model name is configurable in code or local config.
- API key is supplied through local developer config for the MVP.
- No account system.
- No cloud backend.

## Learning

- Local JSON file.
- Storage path: `~/Library/Application Support/CasprFlow/preferences.json`.
- Store:
  - selected context
  - generated draft
  - edited final draft
  - regenerate instruction if present
  - inferred style signals
- No database.
- No embeddings.
- No fine-tuning.

## Source Reuse

Use bulk source reuse only where it saves real time.

Primary source-reuse candidate:

- [Axii](https://github.com/bwarzecha/Axii)
  - License: Apache-2.0.
  - Relevant parts: macOS menu-bar app shell, global hotkey flow, permissions pattern, and paste-into-active-app behavior.

Fallback/reference source:

- [Hold to Talk](https://github.com/jxucoder/hold-to-talk)
  - License: Apache-2.0 per its public site.
  - Relevant parts: floating indicator pattern and paste-anywhere interaction.

Do not port non-Apache source for the MVP.

## Packaging

- Local Xcode build only for day one.
- No notarization.
- No auto-update.
- No installer.

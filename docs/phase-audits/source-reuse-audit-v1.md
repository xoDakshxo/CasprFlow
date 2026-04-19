# CasprFlow Source Reuse Audit
### Phase 0 decision record

## Decision

Use Axii as the primary Apache-2.0 reference and narrow port source for native macOS mechanics, but do not wholesale port the Axii app.

Reason:

- Axii has the right OS-facing shape: menu-bar macOS app, global hotkey, floating panel, accessibility permission checks, clipboard handling, focus checks, and paste insertion.
- Axii also contains a large amount of unrelated dictation, audio, model download, history, settings, updater, and onboarding code.
- CasprFlow is faster and safer if Phase 1 creates a clean native app shell, then ports only the specific OS services needed in later phases.

## Verified Sources

### macos-vision-ocr

- Repo: `https://github.com/bytefer/macos-vision-ocr`
- Local inspection path: `.casprflow-temp/macos-vision-ocr`
- Inspected commit: `91a236a`
- License file inspected: `.casprflow-temp/macos-vision-ocr/LICENSE`
- License: MIT
- Use: reference pattern for Apple Vision OCR request setup and structured output with text, confidence, and position data

### Axii

- Repo: `https://github.com/bwarzecha/Axii`
- Local inspection path: `/tmp/casprflow-axii-inspect`
- License file inspected: `/tmp/casprflow-axii-inspect/LICENSE`
- License: Apache-2.0
- README fit: macOS menu-bar dictation app with hotkey-triggered paste into active app

### Hold to Talk

- Repo/site: `https://github.com/jxucoder/hold-to-talk` and `https://holdtotalk.ai/`
- License signal: public site says Apache 2.0 licensed
- Use: fallback/reference only for floating indicator and paste-anywhere UX if Axii blocks progress

### Permiso

- Repo: `https://github.com/zats/permiso.git`
- Local inspection path: `.casprflow-temp/permiso`
- Inspected commit: `3012871`
- License file inspected: none present in checkout
- License: unresolved
- Use: reference for System Settings privacy pane launch, Settings window tracking, overlay helper, and drag source for adding the current app to Accessibility / Screen Recording
- Caveat: package declares Swift tools 6.2 and `.macOS(.v26)`; CasprFlow should reimplement the narrow behavior locally unless direct dependency compatibility is verified

## Axii Files Worth Reusing

Port or adapt only when the corresponding CasprFlow phase needs the behavior.

### Phase 1: App shell, hotkey, placeholder capsule

- `Axii/Services/HotkeyService.swift`
  - Use for global hotkey service shape.
  - Simplify to one fixed `Option + Space` hotkey.
  - Remove hotkey recording, dynamic mode IDs, and custom mode support.

- `Axii/UI/FloatingPanel.swift`
  - Use for floating `NSPanel` behavior.
  - CasprFlow needs an editable reply capsule, so the panel must be changed to allow key focus when editing.
  - Keep the small floating-panel positioning and SwiftUI hosting pattern.

- `Axii/Services/Permissions/AccessibilityPermissionService.swift`
  - Use for `AXIsProcessTrustedWithOptions` polling and system settings link.
  - Keep permission UI minimal.

### Phase 2: Selected text capture

- `Axii/Services/ClipboardService.swift`
  - Use as a simple save/copy/restore pattern.
  - Extend if needed for transient pasteboard markers.

CasprFlow should implement selected-text capture directly with synthetic `Command + C`; Axii captures richer accessibility context that is useful later but not required for MVP Phase 2.

### Phase 3: Paste into active app

- `Axii/Services/Paste/FocusSnapshot.swift`
  - Use for frontmost app/focused element sanity checks.
  - CasprFlow can start with a simpler previous-app reference and add snapshot checks only if paste reliability needs it.

- `Axii/Services/Paste/TextInsertionService.swift`
  - Use for direct AX insertion followed by clipboard paste fallback.
  - Keep the clipboard fallback as the reliable MVP path.

- `Axii/Services/Paste/PasteService.swift`
  - Use for paste condition checks and outcome modeling.
  - Simplify finish behavior to paste-only with best-effort clipboard restore.

## Axii Files Not To Port

Do not port these for the MVP:

- audio recording
- transcription
- diarization
- model download
- history UI
- settings dashboard
- updater
- Bedrock or LLM provider settings
- onboarding flow beyond permission guidance
- hotkey picker or advanced hotkey mode
- conversation or meeting features

## License Handling

If source code is copied or substantially adapted:

- Preserve original copyright/license headers where present.
- Keep Apache-2.0 license text available.
- Add `THIRD_PARTY_NOTICES.md` before any public distribution.
- Note copied/adapted files in the relevant phase report.
- For `macos-vision-ocr`, keep MIT attribution because `LocalOCRService` intentionally adapts its Vision request/output shape.
- For `permiso`, do not copy or substantially adapt source until license status is clarified or permission is obtained.

If only behavior is reimplemented after inspection:

- No source header is required, but the phase report should mention Axii as a reference.

## Phase 0 Go-Forward

Proceed with:

**Build a clean CasprFlow app shell locally and port only narrow Axii OS mechanics as needed.**

This keeps the MVP small while still saving time on the risky macOS integration work.

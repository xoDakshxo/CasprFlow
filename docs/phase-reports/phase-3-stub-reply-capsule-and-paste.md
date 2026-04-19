# Phase 3 Report: Stub Reply Capsule and Paste

Status: Implemented, manual smoke pending

## Summary

- What changed:
  - Added `StubReplyGenerator` for deterministic non-AI replies.
  - Added `PasteService` for pasteboard backup, final draft paste, previous-app activation, synthetic `Command + V`, and pasteboard restore.
  - Added source app PID to `ScreenContext` so the product capsule can restore focus before paste.
  - Added `PromptContext` and confidence scoring so the app can use automatic AX context without requiring selected text.
  - Removed clipboard copy fallback from the fast capture path so no-selection context stays primary.
  - Imported `bytefer/macos-vision-ocr` into `.casprflow-temp/macos-vision-ocr` as an MIT local reference.
  - Added hotkey-triggered active-window screenshot capture for local OCR only.
  - Added in-process Apple Vision OCR using the `macos-vision-ocr` request/output shape.
  - Added OCR text, confidence, normalized bounding boxes, and capture source labels to `ScreenContext`.
  - Switched OCR to accurate Vision recognition with language correction.
  - Made OCR interaction-first:
    - focused reply/input region
    - cursor-near region when the cursor is inside the active window
  - Added a visible-window-region OCR retry when interaction crops look weak or partial.
  - Merged OCR candidates into `PromptContext` on every capture. Confidence no longer gates whether OCR runs.
  - Replaced the Phase 2 product preview text with an editable stub reply capsule.
  - Added product capsule keyboard handling:
    - `Enter` pastes the current draft.
    - `Command + R` replaces the draft with a different deterministic stub reply.
    - `Escape` closes both product and debug windows without paste.
  - Kept the debug context inspector separate from the product capsule.
  - Added Phase 3 self-check coverage for stub replies, regeneration, paste text validation, and capsule construction.
  - Added checks for no-selection prompt context and chrome pruning.
- What now works:
  - The non-AI product capsule has the same basic interaction shape as the MVP capsule.
  - The product capsule can open from prompt-ready AX context even when no text is selected.
  - The product capsule can also open from prompt-ready OCR context when AX misses text.
  - The debug inspector shows the final prompt context, confidence, capture mode, candidate count, dropped/noisy candidate count, screenshot metadata, OCR candidates, and each OCR candidate's capture source.
  - The app has a dedicated paste path for Phase 3 instead of ad hoc UI logic.
  - The debug inspector still opens beside the product capsule after capture.
- What was intentionally skipped:
  - No Gemini generation.
  - No screenshot-to-Gemini fallback.
  - No local learning.
  - No learned label.
  - No auto-send.
  - No send detection.

## Checks

- Build:
  - Passed: `make build`
  - The build re-signed `.build/CasprFlow.app`; local Accessibility permission may need to be granted again.
  - Build warning: `CGWindowListCreateImage` is deprecated on macOS 14. It is retained for this MVP slice because it keeps active-window capture small; ScreenCaptureKit can replace it during hardening.
- Unit tests:
  - Passed: `make test`
  - `CasprFlowChecks` covers the Phase 3 stub generator, regeneration path, paste text validation, prompt context without selection, chrome pruning, OCR-only prompt context, and capsule construction.
- Manual smoke:
  - Blocked in this agent run. The app binary changed and was re-signed, so macOS must allow Accessibility for `.build/CasprFlow.app` before the hotkey/paste smoke can be trusted.
  - Required local smoke remains:
    - In Notes, place the cursor in an empty reply area with visible message text nearby.
    - Do not select any text.
    - Press `Option + Space`.
    - Confirm the product capsule shows a stub reply and the debug inspector stays separate.
    - Confirm the debug inspector shows `Prompt Context` with non-empty text and confidence.
    - Confirm the debug inspector shows `Screenshots` metadata and `OCR Text` candidates.
    - Confirm rows from `focusedInteractionRegion` or `cursorInteractionRegion` appear before broad fallback rows.
    - If OCR is weak, confirm rows from `visibleWindowRegion` appear as the retry source.
    - Edit the reply.
    - Press `Command + R` and confirm the draft changes.
    - Press `Enter` and confirm the final text pastes into Notes.
    - Confirm `Escape` cancels without paste.
- Docs/skills:
  - Phase stayed within MVP scope: no hotkey picker, no AI generation, no learning, no auto-send, no account/sync/dashboard scope.

## Evidence

- Commands run:
  - `git status --short --branch`
  - `git switch -c codex/phase-3-stub-reply-capsule-paste`
  - `make build`
  - `make test`
  - `git clone https://github.com/bytefer/macos-vision-ocr.git .casprflow-temp/macos-vision-ocr`
- Apps tested:
  - None manually in this run. Notes smoke is the next required local check after Accessibility is granted.
- Files changed:
  - `Sources/CasprFlowCore/ScreenContext.swift`
  - `Sources/CasprFlowCore/SelectionCaptureService.swift`
  - `Sources/CasprFlowCore/ActiveWindowScreenshotService.swift`
  - `Sources/CasprFlowCore/LocalOCRService.swift`
  - `Sources/CasprFlowCore/StubReplyGenerator.swift`
  - `Sources/CasprFlowCore/PasteService.swift`
  - `Sources/CasprFlowCore/PhaseThreeSelfCheck.swift`
  - `Sources/CasprFlowCore/ReplyCapsuleController.swift`
  - `Sources/CasprFlowChecks/main.swift`
  - `docs/phase-reports/phase-3-stub-reply-capsule-and-paste.md`

## Known Issues

- Manual paste validation is pending because macOS Accessibility must be re-granted after re-signing.
- OCR validation is pending because active-window screenshot capture may require Screen Recording / Screen & System Audio Recording permission on the local machine.
- `NSRunningApplication.activate(options: [])` restores the target app on the current macOS API path; paste still needs real Notes smoke confirmation.
- Screenshot-to-Gemini fallback is intentionally not implemented. Screenshots are local-only for Vision OCR in this slice.

## Next Phase Prompt

Use the repo-local CasprFlow skills and execute `docs/phases/phase-4-gemini-generation-service.md`. Generate one Gemini reply from compact mandatory AX+OCR prompt context, keep screenshots local-only unless an explicit low-confidence screenshot fallback phase is requested, run checks, write the phase report, and stop.

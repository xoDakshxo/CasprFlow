# Phase 2 Report: Selected Text Capture

Status: Automated checks passed; manual selection validation pending

## Summary

- What changed:
  - Added `SelectionCaptureService`.
  - Added Accessibility-first selected-text capture for native focused text controls.
  - Added copy-based selected-text capture using synthetic `Command + C` as a fallback.
  - Added pasteboard `changeCount` validation so stale clipboard text is not treated as selected text.
  - Added a short hotkey-release delay before fallback copy to avoid sending `Option + Command + C`.
  - Added best-effort pasteboard item save/restore.
  - Added `SelectionTextNormalizer`.
  - Updated the hotkey flow to show selected text in the capsule.
  - Added empty-selection and permission-needed capsule states.
- What now works:
  - Pressing the fixed hotkey runs the selection capture path before showing the capsule.
  - Selected text is normalized before display.
  - If fallback copy does not update the pasteboard, the app shows the empty-selection state instead of the last copied clipboard value.
  - Empty selected text resolves to `Highlight a message first.`
  - `make test` validates string cleanup behavior and Phase 1 invariants.
- What was intentionally skipped:
  - No Gemini generation.
  - No editable reply field.
  - No paste flow.
  - No local learning.
  - No app-specific accessibility text extraction beyond generic focused-element selected text.

## Checks

- Build:
  - Passed: `make build`
- Unit tests:
  - Passed: `make test`
  - Coverage includes:
    - nil selected text
    - whitespace-only selected text
    - trimming selected text
    - preserving multiline selected text
    - default hotkey descriptor
    - reply capsule construction
    - Carbon hotkey registration/unregistration
- Manual smoke:
  - Not directly automated: the true Notes selection/hotkey smoke test requires manual user validation because this environment cannot send `Option + Space` via System Events.
- Docs/skills:
  - Phase remained within scope: selected-text capture only; no generation, paste, learning, or hotkey picker.

## Evidence

- Commands run:
  - `make build`
  - `make test`
- Files changed:
  - `Sources/CasprFlowChecks/main.swift`
  - `Sources/CasprFlowCore/AppCoordinator.swift`
  - `Sources/CasprFlowCore/SelectionCaptureService.swift`
  - `Sources/CasprFlowCore/SelectionTextNormalizer.swift`
  - `docs/phase-reports/phase-2-selected-text-capture.md`

## Manual Validation Needed

Run this locally:

1. Build and launch:

```sh
make build
make run
```

2. Open Notes.
3. Put a sentinel value on the clipboard:

```sh
printf 'OLD_CLIPBOARD_SENTINEL' | pbcopy
```

4. Type or find:

```text
Can you send me the project update by tonight?
```

5. Highlight that sentence.
6. Press and release `Option + Space`.
7. Confirm the capsule title is `Selected message`.
8. Confirm the capsule shows the selected text, not `OLD_CLIPBOARD_SENTINEL`.
9. Press `Escape`.
10. Trigger with no selected text.
11. Confirm the capsule says `Highlight a message first.`

## Known Issues

- If Accessibility is not trusted, the capsule can show `Accessibility needed`. Grant `.build/CasprFlow.app` in System Settings -> Privacy & Security -> Accessibility.
- Some apps may not expose selected text through Accessibility and may block synthetic copy. In those cases the app now fails closed with `Highlight a message first.` rather than showing stale clipboard content.
- Multiple instances can be launched with `open -n`; use `make run` for normal validation.

## Next Phase Prompt

Use the repo-local CasprFlow skills and execute docs/phases/phase-3-stub-reply-capsule-and-paste.md. Complete only that phase, run its checks, write the phase report, commit the phase, and stop.

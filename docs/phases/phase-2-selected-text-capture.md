# Phase 2: Selected Text Capture

## Outcome

Highlighting text in another app and pressing `Option + Space` shows that selected text inside the capsule.

## Scope

- Save current clipboard string.
- Send synthetic `Command + C`.
- Wait briefly for pasteboard update.
- Read selected text.
- Restore previous clipboard string best-effort.
- Show `Highlight a message first.` if selected text is empty.
- Keep the placeholder capsule. Do not add generation yet.

## Deliverables

- `SelectionCaptureService` or equivalent.
- Unit tests for string cleanup and empty-selection handling where practical.
- `docs/phase-reports/phase-2-selected-text-capture.md`

## Automated Checks

- `make build`
- `make test`

Recommended unit coverage:

- trims whitespace around selected text
- rejects empty selection
- preserves selected text with newlines
- does not crash on missing pasteboard string

## Manual Checks

- Open Notes.
- Type or find text: `Can you send me the project update by tonight?`
- Highlight that text.
- Press `Option + Space`.
- Confirm capsule shows the selected message.
- Press `Escape`.
- Trigger with no selected text.
- Confirm capsule shows `Highlight a message first.`
- Confirm the previous clipboard value is restored when practical.

## Exit Criteria

- Selection-first context works in Notes.
- Empty selection gives a clear capsule state.
- No generation, paste, or learning is required yet.

## Stop If

- Synthetic copy cannot work because permissions are missing.
- Clipboard restore corrupts selected text capture.

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-3-stub-reply-capsule-and-paste.md. Complete only that phase, run its checks, write the phase report, and stop.
```


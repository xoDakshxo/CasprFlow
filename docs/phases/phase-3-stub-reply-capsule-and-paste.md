# Phase 3: Stub Reply Capsule and Paste

## Outcome

The app completes the full OS loop without live AI:

selected text -> stub reply -> edit in capsule -> paste into active app.

## Scope

- Replace selected-message display with a deterministic stub reply.
- Make the capsule text editable.
- Add footer: `Enter paste | Cmd+R regenerate | Esc`.
- Implement `Enter` to paste current capsule text into the previously active app.
- Implement `Escape` cancel.
- Implement temporary stub `Command + R` behavior:
  - if text exists, replace with a visibly different stub reply
  - no model call yet
- Restore focus before paste.
- Restore clipboard best-effort after paste.

## Deliverables

- Editable reply capsule.
- Paste service.
- Focus restore path.
- Stub generator service.
- `docs/phase-reports/phase-3-stub-reply-capsule-and-paste.md`

## Automated Checks

- `make build`
- `make test`

Recommended unit coverage:

- stub generator returns one reply
- paste service prepares expected pasteboard text through injectable abstraction
- keyboard actions route to paste, regenerate, or cancel

## Manual Checks

- In Notes, place cursor in an empty reply area.
- Highlight incoming-message text somewhere else in the note.
- Press `Option + Space`.
- Confirm capsule shows a stub reply, not the raw selected message.
- Edit the reply.
- Press `Command + R`.
- Confirm the capsule text changes.
- Press `Enter`.
- Confirm final text pastes into the active text field.
- Confirm `Escape` cancels without paste.

## Exit Criteria

- The complete non-AI walking skeleton works.
- The hardest OS boundaries are proven:
  - hotkey
  - selected text
  - capsule
  - edit
  - regenerate command
  - focus restore
  - paste

## Stop If

- Paste goes into the capsule instead of the prior app.
- `Enter` risks sending a message in a chat app. Test in Notes first.

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-4-gemini-generation-service.md. Complete only that phase, run its checks, write the phase report, and stop.
```


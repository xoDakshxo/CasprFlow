# Phase 6: Regenerate From Edit

## Outcome

The user can edit the capsule text, press `Command + R`, and receive a regenerated Gemini reply that follows the edit.

## Scope

- Track original selected message.
- Track original generated reply.
- Track current edited capsule text.
- On `Command + R`:
  - if no edit exists, regenerate normally
  - if edit exists, send selected message, generated draft, edited draft, and learned preferences
- Store learning from the edit before or after regeneration.
- Replace capsule text with regenerated reply.
- Keep focus inside the capsule.
- Preserve `Enter` paste behavior.

## Deliverables

- Regeneration prompt builder.
- Regeneration service path.
- UI state for regenerating.
- Learning signal update from edit.
- `docs/phase-reports/phase-6-regenerate-from-edit.md`

## Automated Checks

- `make build`
- `make test`

Recommended unit coverage:

- regenerate prompt includes selected message
- regenerate prompt includes previous generated draft
- regenerate prompt includes user's edited draft
- no-edit regenerate does not include fake correction guidance
- edited regenerate stores a learning signal

## Manual Checks

- Generate a reply.
- Edit it to be shorter or more direct.
- Press `Command + R`.
- Confirm capsule shows loading/regenerating state.
- Confirm regenerated reply reflects the edit.
- Press `Enter`.
- Confirm final reply pastes into active app.
- Trigger next reply.
- Confirm learned label appears.

## Exit Criteria

- The correction loop feels minimal and useful.
- `Command + R` does not open extra UI.
- Pasting still works after regeneration.

## Stop If

- Regeneration creates multiple alternatives.
- Regeneration loses the user's edit intent.
- Keyboard handling becomes unreliable.

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-7-mvp-hardening-and-demo-candidate.md. Complete only that phase, run its checks, write the phase report, and stop.
```


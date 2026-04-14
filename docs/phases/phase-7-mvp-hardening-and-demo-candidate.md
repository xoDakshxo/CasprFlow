# Phase 7: MVP Hardening and Demo Candidate

## Outcome

The MVP is ready to demo end-to-end on the local machine.

## Scope

- Fix bugs found in the full loop.
- Improve empty-selection, missing-permission, missing-key, and network-error states.
- Keep UI minimal.
- Add third-party attribution if Axii or Hold to Talk source was ported.
- Add a short local run note if needed.
- Do not add new product features.

## Deliverables

- Demo-ready app.
- Final phase report.
- Optional `THIRD_PARTY_NOTICES.md` if source was ported.
- Optional local run note in existing docs if needed.
- `docs/phase-reports/phase-7-mvp-hardening-and-demo-candidate.md`

## Automated Checks

- `make build`
- `make test`
- any formatter or lint command introduced by earlier phases

## Manual Checks

Run this exact demo in Notes:

1. Put the cursor where the reply should be pasted.
2. Highlight: `Can you send me the project update by tonight?`
3. Press `Option + Space`.
4. Confirm one generated reply appears in the capsule.
5. Edit the reply to make it shorter.
6. Press `Command + R`.
7. Confirm the regenerated reply reflects the edit.
8. Press `Enter`.
9. Confirm final reply pastes into the text field.
10. Trigger another reply.
11. Confirm a learned label appears.

Also test:

- Browser text field.
- Slack or Messages if available.
- Empty selection.
- Escape cancel.
- Missing `GEMINI_API_KEY`.
- API/network failure if practical.
- Clear learning.

## Exit Criteria

- The complete MVP loop works twice in a row.
- Tests pass.
- Known issues are documented.
- No excluded scope was added.
- The app is demoable by the user.

## Stop If

- The app cannot paste reliably into Notes.
- The app crashes during the core loop.
- Missing permissions cannot be explained clearly.

## Final Demo Prompt

```text
Use the repo-local CasprFlow skills and run the final MVP demo checklist from docs/phases/phase-7-mvp-hardening-and-demo-candidate.md. Fix only blocking issues, rerun checks, update the Phase 7 report, and stop.
```


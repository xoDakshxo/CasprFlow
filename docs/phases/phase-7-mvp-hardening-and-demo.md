# Phase 7: MVP Hardening And Demo

## Outcome

The full loop runs reliably twice in a row across at least three real apps, with readable error states, an attribution file, and a demo script.

## Scope

### Reliability

- focus restoration after expansion (capsule should not steal focus from the source field on close)
- pasteboard restore works when the user had non-trivial clipboard content
- chip request timeout: cancel after 4 s, fall back to deterministic chips
- expansion timeout: cancel after 6 s, show error
- accessibility-permission lost mid-session shows a clear capsule message

### Demo apps

Smoke against:

1. Slack (chat)
2. Apple Messages (casual)
3. Notes (other)
4. VS Code prompt area (code)
5. Mail compose (email)

### Polish

- `THIRD_PARTY_NOTICES.md` listing Axii (Apache-2.0) and macos-vision-ocr (MIT)
- README links to Product Model + Tech Spec + Phases
- `Scripts/` build/run instructions verified

### Failure UX

- missing API key: capsule shows `Set GEMINI_API_KEY to enable replies.` with `Esc`
- network error: `Couldn't reach Gemini. Try again.` with `Cmd+R` to retry
- empty bundle: `Need more context — focus a chat or reply field.`

## Non-Goals

- no notarization
- no installer
- no auto-update
- no code signing beyond local

## Deliverables

- updated `ReplyCapsuleController` error states
- timeout wrappers in `GenerationService`
- `THIRD_PARTY_NOTICES.md`
- updated README demo script
- `docs/phase-reports/phase-7-mvp-hardening-and-demo.md`

## Automated Checks

- `make build`
- `make test`

## Manual Checks

Run the full loop twice per app for the five demo apps above. Confirm:

- chips appear within ~800 ms when Gemini is fast
- `Enter` pastes into the original field
- `learned: …` appears after at least one edit cycle
- `Esc` always closes cleanly

## Exit Criteria

- the loop works twice in three or more demo apps
- error states are readable
- attribution file exists

## Stop If

- a target app reliably blocks paste (document it instead of fighting it)
- timeouts cannot be respected because of Gemini SDK behavior (note as known issue)

## Next Phase Prompt

The MVP is complete after Phase 7. No next phase by default — propose new scope explicitly.

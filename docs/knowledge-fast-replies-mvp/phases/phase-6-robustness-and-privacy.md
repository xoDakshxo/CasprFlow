# Phase 6: Robustness And Privacy

## Outcome

The MVP handles expected failure modes cleanly and protects local/private data by default.

## Why This Comes Now

The core loop exists after Phase 5. This phase makes it robust enough for repeated real-app use.

## Scope

Harden:

- missing API key
- build-context timeout
- build-output timeout
- malformed `ReplyPlan`
- malformed `ContextBrief`
- custom input follow-up failure
- edit/regenerate follow-up failure
- missing Accessibility permission
- missing Screen Recording permission
- no screenshot available
- no AX text available
- corrupt learning file
- paste target unavailable
- obvious secret redaction
- learning reset

Do not add new product features.

## Implementation Steps

1. Add explicit timeout wrappers:
   - capture timeout if needed
   - build-context timeout
   - build-output timeout
   - custom/follow-up timeout
   - paste timeout if needed
2. Add user-facing error states:
   - `Set OPENAI_API_KEY to enable replies.`
   - `Couldn't reach OpenAI. Try again.`
   - `Need Accessibility permission.`
   - `Need Screen Recording for screenshot context.`
3. Make `Cmd+R` retry the failed step when appropriate:
   - reuse valid `ContextBrief` if only build-output failed
   - rerun build-context if context is missing or stale
4. Make malformed context output fall back to local capture summary with low confidence.
5. Make malformed reply output fall back to deterministic chips and editable fallback drafts.
6. Make custom input and edit/regenerate failures preserve the current draft and show a retryable error.
7. Confirm text-only path works without Screen Recording when AX is enough.
8. Confirm screenshot path explains missing Screen Recording.
9. Add redaction tests for common secret shapes.
10. Confirm no raw screenshot bytes are persisted in learning.
11. Add menu reset for learning and any cached local knowledge.
12. Add debug latency and failure reason fields.
13. Write the phase report.

## Automated Checks

- `make build`
- `make test`

Focused checks should prove:

- missing API key maps to the right UI message.
- timeout maps to retryable UI.
- malformed context maps to a low-confidence local summary.
- malformed plan maps to fallback chips.
- custom input failure does not delete the current draft.
- edit/regenerate failure does not delete the current draft.
- redaction removes obvious secrets before request construction.
- learning store never persists screenshot bytes.
- corrupt learning data is recoverable.

## Manual Test

1. Unset `OPENAI_API_KEY`.
2. Press `Option + Space`.
3. Confirm a clear missing-key state appears and the app does not crash.
4. Restore `OPENAI_API_KEY`.
5. Block network or use a forced timeout config for build-context.
6. Confirm retry works with `Cmd+R`.
7. Force build-output failure after context succeeds.
8. Confirm retry reuses the existing context.
9. Revoke or simulate missing Screen Recording.
10. Confirm text-only surfaces still work when AX is sufficient.
11. Confirm screenshot-needed surfaces explain the permission gap.
12. Clear learning and confirm label/memory disappears.

## Exit Condition

The user can manually trigger and recover from key failure modes without relaunching the app or losing control of the paste target.

## Stop If

- A failure mode requires force-quitting the app.
- Missing Screen Recording blocks text-only usage.
- Reset does not clear visible learned behavior.
- Any capture path mutates the clipboard.

## Not Yet Implemented

- no final cross-app demo report
- no packaging closeout

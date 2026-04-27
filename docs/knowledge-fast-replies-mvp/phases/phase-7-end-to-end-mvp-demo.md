# Phase 7: End-To-End MVP Demo

## Outcome

The full knowledge fast replies MVP is manually verified across real apps and ready for handoff.

## Why This Comes Last

This phase should not invent core behavior. It proves the behavior implemented in Phases 0-6 works together.

## Scope

Close out:

- real-app manual test matrix
- latency notes
- known issues
- packaging/run instructions
- final phase report

Only fix bugs found during the demo pass. Do not add new product scope.

## Implementation Steps

1. Build the app from a clean terminal.
2. Run the test suite.
3. Launch the app bundle.
4. Confirm required permissions:
   - Accessibility
   - Screen Recording
5. Run the manual matrix below.
6. Record latency observations from debug UI.
7. Fix blocking bugs only.
8. Write final report under `docs/knowledge-fast-replies-mvp/reports/phase-7-end-to-end-mvp-demo.md`.
9. Update `scope.md` only if the actual final behavior differs from the planned MVP.

## Automated Checks

- `make build`
- `make test`

If packaging scripts are used:

- run the local app bundle creation script
- record the exact command in the report

## Manual Test Matrix

### Slack Or Work Chat

1. Put cursor in a reply field.
2. Press `Option + Space`.
3. Confirm fallback chips appear quickly.
4. Confirm debug evidence shows a correct `ContextBrief`.
5. Confirm hydrated chips match work coordination.
6. Confirm all three hydrated chips have available drafts.
7. Switch chips and confirm drafts swap instantly.
8. Confirm default draft is concise and relevant.
9. Type a custom instruction in the input bar and confirm it produces a custom draft.
10. Edit shorter.
11. Press `Enter`.
12. Confirm paste lands in the original field.
13. Invoke again and confirm learned style is visible/applied.

### Messages Or Casual Chat

1. Put cursor in a casual reply field.
2. Press `Option + Space`.
3. Confirm context identifies the casual reply target.
4. Confirm chips are casual.
5. Confirm draft is short and human.
6. Confirm work-chat style does not dominate.
7. Paste only with `Enter`.

### Code Or Agent Prompt Box

1. Put cursor in a coding/agent prompt field.
2. Press `Option + Space`.
3. Confirm context identifies the active coding/agentic target.
4. Confirm chips are implementation-oriented.
5. Pick `Implement`, `Inspect first`, or equivalent.
6. Confirm the chosen draft is already available without another first-pass model call.
7. Confirm expansion is an agent-ready instruction, not a casual chat reply.
8. Paste only with `Enter`.

### Permissions And Recovery

1. Test missing API key.
2. Test network timeout or forced timeout.
3. Test missing Screen Recording on a screenshot-needed surface.
4. Test text-only fallback when AX is enough.
5. Test `Clear learning`.

## Exit Condition

The user can run the app and manually complete the Slack/work, Messages/casual, code/agent, learning, clear-learning, and recovery flows. At this point the MVP is ready.

## Stop If

- Any core manual flow fails.
- The app sends instead of pastes.
- Capture mutates clipboard.
- Learned behavior cannot be cleared.
- The final report cannot name exactly what was tested.

## Final Report Must Include

- exact branch
- commands run
- apps tested
- screenshots/source modes observed
- context brief quality observed
- latency observations
- learned signals observed
- remaining known issues
- whether the MVP is ready or blocked

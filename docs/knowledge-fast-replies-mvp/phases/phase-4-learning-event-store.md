# Phase 4: Learning Event Store

## Outcome

After paste, CasprFlow writes a local learning event and infers simple style signals from the generated draft versus the final pasted text.

## Why This Comes Now

Learning requires real paste events. This phase records the correction signal but does not yet feed it back into generation.

## Scope

Implement local persistence:

- `LearningEventStore`
- `StyleSignalInferrer`
- `LearningSummary`
- cap stored history
- menu action to clear learning
- visible debug evidence that an event was written

Do not retrieve these signals into OpenAI prompts until Phase 5.

## Storage

Start lean with JSON:

```text
~/Library/Application Support/CasprFlow/learning.json
```

Cap raw examples to the most recent 200 events.

The schema must be versioned so SQLite can replace it later without changing the UI contract.

## Implementation Steps

1. Add `LearningEventStore`.
2. Add file creation under Application Support.
3. Add resilient load:
   - missing file means empty store
   - corrupt file is renamed aside and replaced with empty store
4. Add `StyleSignalInferrer`.
5. Infer at least:
   - `shorter`
   - `more_context`
   - `no_emojis`
   - `more_direct`
   - `warmer`
   - `less_excited`
6. Wire paste path to write the event after a successful paste request.
7. Store shown draft, generated draft, and final text separately.
8. Add `Clear learning` menu item if not already present or wire existing item to the new store.
9. Add debug UI evidence:
   - latest event id
   - latest signals
   - current strongest signal
10. Add tests for signal inference and store behavior.
11. Write the phase report.

## Automated Checks

- `make build`
- `make test`

Focused checks should prove:

- shorter final text creates `shorter`.
- removing `!` creates `less_excited`.
- removing emoji creates `no_emojis`.
- store caps examples at 200.
- corrupt JSON does not crash the app.
- clear learning empties examples and summary.
- event records which chip/draft was actually shown before paste.

## Manual Test

1. Generate a draft in Slack/work chat.
2. Edit it to be shorter.
3. Press `Enter`.
4. Confirm the text pasted.
5. Open debug/menu evidence and confirm a learning event was written.
6. Confirm the strongest signal is `shorter`.
7. Click `Clear learning`.
8. Confirm the stored signal disappears.

## Exit Condition

The user can manually produce a learning event from a real edited paste and clear it.

## Stop If

- Learning writes before paste succeeds.
- The app stores raw screenshots by default.
- Corrupt learning data prevents the app from launching.

## Not Yet Implemented

- generated replies do not use learned signals yet
- no person/project memory yet
- no robust timeout/privacy pass beyond store resilience

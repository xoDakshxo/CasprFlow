# Phase 5: Local Learning Store

## Outcome

Editing a generated reply stores a local learning signal, and the next generation can include that preference.

## Scope

- Create local JSON store:
  - `~/Library/Application Support/CasprFlow/preferences.json`
- Store examples:
  - created time
  - selected context
  - generated reply
  - edited final reply
  - inferred signals
- Store summary counts.
- Infer only MVP signals:
  - `shorter`
  - `longer`
  - `more_direct`
  - `warmer`
  - `no_emojis`
  - `less_excited`
- Convert summary into prompt-ready preferences.
- Show one learned label in the capsule.
- Add Clear learning menu action.

## Deliverables

- `LearningStore`
- `SignalInference`
- prompt preference summary
- learned label binding
- clear-learning behavior
- `docs/phase-reports/phase-5-local-learning-store.md`

## Automated Checks

- `make build`
- `make test`

Recommended unit coverage:

- shorter signal when edited text is at least 20 percent shorter
- longer signal when edited text is at least 20 percent longer
- no-emojis signal when generated emojis are removed
- more-direct signal when hedging phrases are removed
- less-excited signal when exclamation marks are removed
- JSON round trip
- clear-learning deletes or resets the local store

## Manual Checks

- Generate a reply.
- Edit it shorter.
- Press `Enter`.
- Confirm JSON file exists.
- Confirm signal summary includes `shorter`.
- Trigger another generation.
- Confirm capsule shows `learned: shorter`.
- Use Clear learning.
- Confirm learned label disappears.

## Exit Criteria

- Learning is local and inspectable.
- At least one signal visibly affects the next Gemini prompt.
- Clear learning works.

## Stop If

- Learning requires embeddings, database, fine-tuning, or cloud storage.
- The learned label overclaims beyond simple heuristics.

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-6-regenerate-from-edit.md. Complete only that phase, run its checks, write the phase report, and stop.
```


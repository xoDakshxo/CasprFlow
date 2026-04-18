# Phase 6: Local Learning

## Outcome

CasprFlow stores edit deltas locally, infers a small set of style signals, and feeds the strongest signal into the next expansion. One learned label is visible in the capsule.

## Scope

### Storage

- `~/Library/Application Support/CasprFlow/preferences.json`
- shape:

```json
{
  "examples": [
    {
      "createdAt": "2026-04-18T20:00:00Z",
      "surfaceKind": "chat",
      "chip": "Take it",
      "generated": "...",
      "final": "...",
      "signals": ["shorter", "more_direct"]
    }
  ],
  "summary": {
    "shorter": 3,
    "more_direct": 1,
    "no_emojis": 2,
    "warmer": 1,
    "less_excited": 0
  }
}
```

### Signal heuristics

- `shorter`: final ≤ 0.8× generated length
- `more_context`: final ≥ 1.2× generated length
- `no_emojis`: emojis present in generated, absent in final
- `more_direct`: removed any of `I think | maybe | just | if that works`
- `warmer`: added any of `thanks | appreciate | sounds good | happy to`
- `less_excited`: removed `!`

### Wiring

- Paste path computes signals from `(generated, final)`, updates the JSON store.
- Expansion prompt receives a `learned` block summarizing the strongest signal:

```text
Learned style preferences (apply when relevant):
- {strongest_signal}
```

- Capsule shows a small `learned: shorter` chip when at least one signal exists.

### Menu

- Add `Clear learning` menu item that wipes `preferences.json` after confirm.

## Non-Goals

- no embeddings
- no per-relationship memory
- no remote sync
- no settings UI for tuning weights

## Deliverables

- `LearningStore.swift`
- `StyleSignalInferrer.swift`
- updated expansion prompt builder
- updated capsule with learned-label slot
- updated menu with `Clear learning`
- `docs/phase-reports/phase-6-local-learning.md`

## Automated Checks

- `make build`
- `make test`

Recommended unit coverage:

- inferrer returns `shorter` when final is much shorter
- inferrer returns `no_emojis` when emojis are removed
- store appends an example without dropping older entries
- store summary increments correctly
- strongest signal selection is deterministic on tie (first by name)
- expansion prompt embeds the strongest signal

## Manual Checks

- Generate a chat expansion. Edit it shorter. `Enter`.
- Generate again. Confirm capsule shows `learned: shorter`.
- Confirm `Clear learning` empties the file.

## Exit Criteria

- editing a draft creates at least one signal
- the next generation reflects the signal
- `Clear learning` works

## Stop If

- the JSON file grows uncontrollably (cap at last 200 examples)
- signal heuristics fight each other and create unstable labels

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-7-mvp-hardening-and-demo.md. Complete only that phase, run its checks, write the phase report, and stop.
```

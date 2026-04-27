# Phase 5: Local Knowledge Retrieval

## Outcome

The next reply uses local knowledge from previous events: user style, app-specific tone, person hints, project hints, and recent chips.

## Why This Comes Now

Phase 4 records learning. This phase makes that learning affect generation without adding remote memory or a second runtime.

## Scope

Implement local retrieval and prompt injection:

- `LocalKnowledgeRetriever`
- `KnowledgeContext` populated from `LearningEventStore`
- strongest global style signal
- surface/app-specific style signal
- simple entity extraction from stored event summaries
- recent chip momentum
- visible learned label in the capsule

Keep this deterministic. Do not add embeddings yet.

## Implementation Steps

1. Add `LocalKnowledgeRetriever`.
2. Read current learning summary and recent events.
3. Match context by:
   - surface kind
   - app bundle id
   - window title tokens
   - names found in target summaries
   - project/repo-like tokens
4. Populate `KnowledgeContext` with a small capped set of hints.
5. Add a prompt section to `OpenAIOutputPlanner`:
   - learned style
   - app/person/project hints
   - recent selected chips
   - `ContextBrief` target summary
6. Keep prompt additions short and auditable.
7. Make the model return a `learnedLabel` only when a signal was actually retrieved.
8. Show that learned label in the capsule.
9. Add debug evidence showing which memory ids were used.
10. Add tests for deterministic retrieval.
11. Write the phase report.

## Automated Checks

- `make build`
- `make test`

Focused checks should prove:

- empty store returns empty `KnowledgeContext`.
- global strongest signal is retrieved.
- app-specific signal wins over global when both exist.
- recent chip momentum is capped.
- prompt includes retrieved knowledge only when present.
- learned label is absent when no memory exists.

## Manual Test

1. Clear learning.
2. Generate a Slack/work-chat draft.
3. Edit it shorter and paste.
4. Invoke CasprFlow again in the same surface.
5. Confirm the capsule shows `learned: shorter` or equivalent.
6. Confirm the next generated draft is shorter or more direct.
7. Repeat in Messages with a casual edit and confirm work-chat style does not blindly override casual style.

## Exit Condition

The user can manually see learning affect a later generation, scoped enough that one surface does not obviously poison another.

## Stop If

- Retrieval requires remote calls.
- The prompt grows with unbounded history.
- A learned label appears when nothing was retrieved.
- Work tone leaks badly into casual Messages in the manual test.

## Not Yet Implemented

- no embeddings
- no cloud sync
- no settings UI for memory
- no final robustness demo

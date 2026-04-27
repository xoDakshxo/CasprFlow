# Phase 2: Two-Call Context And Output

## Outcome

The hot path can run exactly two OpenAI calls:

1. `build-context`: parse the focused screenshot and compact AX metadata into a strict `ContextBrief`.
2. `build-output`: use `CapturePack`, `ContextBrief`, and empty `KnowledgeContext` to return a strict `ReplyPlan` with three chips and one draft per chip.

## Why This Comes Now

The screenshot should be understood before the reply is written. A dedicated context parser should improve target selection, speaker detection, and app-specific behavior without letting the reply writer spend tokens rediscovering the screen.

## Scope

Implement generation behind two new services:

- `OpenAIContextBuilder`
- `OpenAIOutputPlanner`
- strict structured output schemas for `ContextBrief` and `ReplyPlan`
- request bodies based on `CapturePack` and empty `KnowledgeContext`
- parser and fallback handling for both calls
- adapter methods so existing UI can still ask for chips and expansion while Phase 3 is pending
- model routing fields for context model, output model, and smaller follow-up model

Do not implement local learning or knowledge retrieval yet. Pass an empty `KnowledgeContext`.

## Build-Context Rules

The context call receives:

- at most one focused screenshot crop
- compact AX fields
- selected text, if available
- app/window metadata
- screenshot decision metadata

It returns:

- active surface kind
- reply target summary
- target confidence
- visible relevant messages/task snippets
- speaker/actor hints
- latest content direction: incoming, outgoing, selected, or ambiguous
- ignored UI/chrome summary
- missing context flags
- screenshot confidence

It must not return chips, drafts, rewritten text, or advice.

## Build-Output Rules

The output call receives:

- `CapturePack`
- `ContextBrief`
- empty `KnowledgeContext` in this phase

It returns:

- exactly three chips
- exactly one concise draft per chip
- default chip id
- target summary
- learned label, empty in this phase
- warnings/fallback reason when relevant

The output call should not receive the raw screenshot by default. If the context brief says the screenshot parse is low-confidence, the output planner may use text fallbacks and conservative chips rather than making a third call.

## Implementation Steps

1. Add `OpenAIContextBuilder` conforming to `ContextBuilding`.
2. Add `OpenAIOutputPlanner` conforming to `OutputPlanning`.
3. Load API key and model roles from existing OpenAI config paths.
4. Build a compact context prompt from:
   - static context-parser rules
   - `CapturePack`
   - optional screenshot
5. Build a compact output prompt from:
   - static product rules
   - `CapturePack`
   - `ContextBrief`
   - empty `KnowledgeContext`
6. Use Responses API with `store: false` for both calls.
7. Request strict JSON schemas for both outputs.
8. Keep `build-context` max output tiny.
9. Keep `build-output` token budget tight, but large enough for three concise drafts.
10. Parse and validate `ContextBrief`.
11. Parse and validate `ReplyPlan`:
    - exactly three chips
    - default chip id exists
    - every chip has one non-empty draft
    - target summary is present
12. On malformed context output, fall back to local capture summary with low confidence.
13. On malformed reply output, fall back to deterministic chips plus editable fallback drafts.
14. Add local self-checks for request shape, parser behavior, and fallback behavior.
15. Write the phase report.

## Automated Checks

- `make build`
- `make test`

Focused checks should prove:

- build-context request includes one screenshot when available.
- build-context request includes no reply-writing instruction.
- build-output request includes `ContextBrief`.
- build-output request includes `store: false`.
- build-output request sends no screenshot by default.
- malformed context JSON falls back safely.
- malformed reply JSON falls back safely.
- duplicate chips are rejected or repaired deterministically.
- plans missing a draft for any chip are rejected or repaired.
- context, output, and follow-up model roles are distinct config values.

## Manual Test

With `OPENAI_API_KEY` configured:

1. Launch the app.
2. Put the cursor in a Slack/work-chat reply field.
3. Press `Option + Space`.
4. Confirm debug evidence shows a `ContextBrief` with the correct latest reply target.
5. Confirm the generated plan has work-style chips and three work-style drafts.
6. Repeat in Messages or a casual text surface.
7. Repeat in a code/agent prompt box.

## Exit Condition

The user can manually trigger the two-call path and see a correct context brief plus a relevant three-draft plan for chat, casual, and code surfaces, even if the UI still uses the old adapter path.

## Stop If

- The implementation needs more than two remote model calls for the first answer.
- The context parser writes chips or reply drafts.
- The output planner requires raw screenshot input by default.
- Chip switching would require another model call after the first plan returns.
- Missing API key crashes the capsule.

## Not Yet Implemented

- no fast hydrated capsule
- no persisted learning event
- no retrieved knowledge context
- no full robustness pass

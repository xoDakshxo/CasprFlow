# Phase 3: Fast Capsule Flow

## Outcome

The capsule renders immediately with deterministic fallback chips, then shows context-building and output-building progress. When the `ReplyPlan` returns, switching among the three chips swaps drafts locally.

## Why This Comes Now

The user should never stare at a dead loading state. This phase improves perceived speed without pretending the remote model is always sub-500 ms.

## Scope

Wire the context/output planning services into `ReplyCapsuleController`:

- immediate fallback chips from local surface kind
- visible `Building context...` and `Writing options...` states
- hydrated chips and three drafts from `ReplyPlan`
- chip selection behavior that swaps to the already returned draft
- custom input bar that can request a custom draft from the output model using the existing `ContextBrief`
- regenerate/edit behavior placeholder for the smaller follow-up route
- latency display in debug UI

Do not store learning events yet. Do not retrieve knowledge yet.

## Implementation Steps

1. Add a `ReplyPlanningServicing` or equivalent adapter used by `ReplyCapsuleController`.
2. On capsule open, render fallback chips immediately from surface kind.
3. Start `buildContext` asynchronously.
4. When context returns, keep fallback chips visible and show the context summary in debug UI.
5. Start `buildOutput` asynchronously using the `ContextBrief`.
6. When the plan returns:
   - replace fallback chips with plan chips
   - set active chip to `default_chip_id`
   - place the default chip's draft in the editor
   - keep the other two drafts available locally
   - show learned label only if the plan has one, which should be empty until Phase 5
7. If the user picks a chip before the plan returns, preserve the user's pick where possible.
8. After the plan returns, choosing chip 1/2/3 swaps to that chip's returned draft with no model call.
9. Add the custom input bar:
   - empty by default
   - accepts a short user instruction
   - submits to a custom-draft follow-up route using the existing `ContextBrief`
   - does not destroy the original three-draft plan
10. Keep edit/regenerate UI wired to a placeholder smaller-model route if the implementation is ready; otherwise leave the controls disabled with a clear reason until Phase 6 hardening.
11. Keep `Enter` paste-only.
12. Keep `Esc` close behavior.
13. Add debug timings:
   - capture duration
   - pack build duration
   - build-context duration
   - build-output duration
   - custom/follow-up duration when used
   - total time to first draft
14. Add self-checks for fallback-to-context-to-output state transitions and local chip draft switching.
15. Write the phase report.

## Automated Checks

- `make build`
- `make test`

Focused checks should prove:

- fallback chips render without network.
- hydrated plan replaces fallback chips.
- context summary appears before output when build-context succeeds.
- hydrated chip switching does not call the model.
- user edit is not overwritten after editing starts.
- custom input produces a separate draft without deleting the three returned drafts.
- missing API key shows a recoverable error.
- `Enter` still calls paste and does not auto-send.

## Manual Test

1. Disconnect or unset `OPENAI_API_KEY`.
2. Press `Option + Space` in Notes.
3. Confirm fallback chips appear and an API-key error is recoverable.
4. Set `OPENAI_API_KEY`.
5. Press `Option + Space` in Slack/work chat.
6. Confirm fallback chips appear first.
7. Confirm debug evidence shows `ContextBrief`.
8. Confirm the real three-chip plan appears.
9. Click or press `1`/`2`/`3` and confirm drafts swap immediately.
10. Type a short custom instruction in the input bar and submit it.
11. Confirm a custom draft appears without losing the original three drafts.
12. Edit the draft and press `Enter`.
13. Confirm text pastes into the original field.

## Exit Condition

The user can manually feel the fast local response, see context and output hydration, switch among three returned drafts locally, optionally submit custom input, edit the draft, and paste successfully.

## Stop If

- The capsule blocks until OpenAI returns.
- The model result overwrites user edits.
- Chip switching after hydration calls the model.
- Custom input deletes the original three drafts.
- Paste target focus restoration regresses.

## Not Yet Implemented

- no durable learning from pasted text
- no retrieved knowledge context
- no full timeout/privacy hardening

# Phase 5: Three Intent Chips

## Outcome

After Phase 4 produces a `ScreenContextBundle`, Gemini turns it into three short intent chips. Picking a chip produces one expansion the user can paste. There is no separate "regenerate" step — re-picking or editing then picking is the regeneration loop.

## Why

Phase 4 hands consumers a clean bundle. The product model in `docs/CasprFlow-Product-Model-v1.md` says the right interaction is `context -> 3 chips -> pick -> full expansion`, not a single AI draft. This phase replaces the stub draft with that two-stage flow.

## Scope

### Generation service

Add `Sources/CasprFlowCore/GenerationService.swift`:

- `URLSession` calls to Gemini `generateContent`
- header `x-goog-api-key`, key from `GEMINI_API_KEY` or local config file (gitignored)
- default model `gemini-3-flash-preview`
- mock implementation for tests (`MockGenerationService`)
- two methods:
  - `chips(for bundle: ScreenContextBundle) async throws -> [Chip]`  (returns exactly 3, each 1–3 words)
  - `expand(chip: Chip, bundle: ScreenContextBundle, edit: String?) async throws -> String` (returns one final reply)

### Prompts

Two distinct prompts. Both take the bundle's compact `prompt` field as the source of truth.

**Chip prompt** (returns JSON `{"chips":["..","..",".."]}`):

```text
You output exactly three short intent chips.
Each chip is 1–3 words, action-level, and easy to pick instantly.
Tailor chips to the surface kind below.

Surface kind: {kind}
App: {app}
Window: {window}
Visible context:
{prompt}

Return only JSON: {"chips":["..","..",".."]}.
```

**Expansion prompt** (returns plain text, one reply):

```text
You expand the user's chosen intent into one final reply.
Match the surface kind tone:
- chat: brief, coordination-style
- code: imperative agent instruction
- email: structured and polite
- casual: short and natural
- other: clear and direct

Surface kind: {kind}
App: {app}
Visible context:
{prompt}
Chosen intent: {chip}
{edited_draft_block}

Write the reply only. No quotes, no markdown, no alternatives.
```

When `edit` is non-empty, append:

```text
The user already started a draft below. Keep its meaning and tone, fix or extend it.
{edit}
```

### Chip vocabulary fallback

When Gemini fails or returns malformed output, fall back to a deterministic surface-aware chip set:

```text
chat:        ["Take it", "Push timing", "Ask context"]
code:        ["Implement", "Inspect first", "Plan steps"]
email:       ["Confirm", "Defer", "Decline"]
casual:      ["Yes", "Soft no", "Not sure"]
browserChat: ["Confirm", "Clarify", "Push back"]
docs:        ["Summarize", "Expand", "Rewrite"]
other:       ["Confirm", "Clarify", "Decline"]
```

### Capsule UI

Update `ProductReplyCapsuleView`:

1. Initial render: `Drafting…` while chips are being requested.
2. Chips state: three pill buttons in a row, with `1` `2` `3` underlines for keyboard pick.
3. Pick state: `Expanding…` while expansion runs.
4. Editing state: existing editable draft, with `Cmd+R` re-running expansion (uses current edit text).
5. `Tab` cycles to the next chip (re-runs expansion).
6. `Esc` closes.
7. `Enter` pastes.

### Wiring

`SelectionCaptureService` returns the bundle (already added in Phase 4). `ReplyCapsuleController` calls `GenerationService.chips(...)` immediately after capture, then `expand(...)` on pick.

### Config

API key resolution order:

1. `GEMINI_API_KEY` env var
2. `~/Library/Application Support/CasprFlow/config.json` → `gemini_api_key`

Missing key → capsule shows readable error and offers `Esc`.

## Non-Goals

- no settings UI
- no model picker
- no streaming
- no learning yet (Phase 6)
- no screenshot attached to Gemini

## Deliverables

- `GenerationService` + `MockGenerationService`
- chip + expansion prompt builders
- updated `ProductReplyCapsuleView`
- `PhaseFiveSelfCheck` with mock-backed coverage
- `docs/phase-reports/phase-5-three-intent-chips.md`

## Automated Checks

- `make build`
- `make test`

Recommended unit coverage:

- chip prompt includes the bundle's `prompt`
- chip prompt asks for exactly three chips
- malformed JSON falls back to deterministic chip set
- fallback chips for Slack bundle id are the chat set
- expansion prompt includes the chosen chip
- expansion prompt with non-empty edit includes the edit block
- mock service round-trips chips and expansion

## Manual Checks

With `GEMINI_API_KEY` set:

- Slack reply field → press hotkey → see three chat-style chips → press `1` → see one expansion → `Enter` pastes.
- iMessage reply field → see casual chips → pick one → expansion is short and casual.
- Code editor with a prompt box → see code-style chips → pick `Implement` → expansion is imperative.

Without an API key:

- Confirm error state is readable and `Esc` closes.

## Exit Criteria

- chips appear within ~800 ms when Gemini is fast
- chips and expansions match the surface kind in at least Slack / Messages / VS Code / Notes
- the user never has to read three full drafts to choose

## Stop If

- chip latency consistently exceeds ~1.5 s
- model returns long sentences instead of chip labels even after prompt tightening
- key handling between chips and editor becomes unreliable

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-6-local-learning.md. Complete only that phase, run its checks, write the phase report, and stop.
```

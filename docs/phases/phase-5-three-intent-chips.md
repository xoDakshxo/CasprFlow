# Phase 5: Three Intent Chips

## Outcome

After Phase 4 produces a `ScreenContextBundle`, OpenAI turns it into three short intent chips. Picking a chip produces one expansion the user can paste. There is no separate "regenerate" step - re-picking or editing then picking is the regeneration loop.

## Why

Phase 4 hands consumers a clean bundle. The product model in `docs/CasprFlow-Product-Model-v1.md` says the right interaction is `context -> 3 chips -> pick -> full expansion`, not a single AI draft. This phase replaces the stub draft with that two-stage flow.

The generation provider is OpenAI as of Phase 5. Use `gpt-5.4-nano` by default because it is the cheap GPT-5.4-class model and supports text plus image input.

## Scope

### Generation service

Add `Sources/CasprFlowCore/GenerationService.swift`:

- `URLSession` calls to OpenAI Responses API (`/v1/responses`)
- `Authorization: Bearer <key>`, key from `OPENAI_API_KEY` or local config file (gitignored)
- default model `gpt-5.4-nano`
- mock implementation for tests (`MockGenerationService`)
- two methods:
  - `chips(for bundle: ScreenContextBundle, screenshots: [ScreenshotAttachment]) async throws -> [Chip]` (returns exactly 3, each 1-3 words)
  - `expand(chip: Chip, bundle: ScreenContextBundle, edit: String?, previousDraft: String?, screenshots: [ScreenshotAttachment]) async throws -> String` (returns one final reply)

### Prompts

Two distinct prompts. Both use one compressed screenshot crop plus AX context. OCR stays local for diagnostics and is not sent to the model.

**Chip prompt** (returns JSON `{"chips":["..","..",".."]}`):

```text
You output exactly three short intent chips.
Each chip is 1-3 words, action-level, and easy to pick instantly.
Tailor chips to the surface kind below.
Use the screenshot as the visual source of truth and AX context as supporting metadata/text. Do not use OCR text.

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
- browserChat: brief, direct, and matched to the chat tone
- code: imperative agent instruction
- email: structured and polite
- casual: short and natural
- docs: clear and useful for the document surface
- other: clear and direct
Use the screenshot as the visual source of truth and AX context as supporting metadata/text. Do not use OCR text.

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

When OpenAI fails during chip creation or returns malformed output, fall back to a deterministic surface-aware chip set:

```text
chat:        ["Take it", "Push timing", "Ask context"]
code:        ["Implement", "Inspect first", "Plan steps"]
email:       ["Confirm", "Defer", "Decline"]
casual:      ["Yes", "Soft no", "Not sure"]
browserChat: ["Confirm", "Clarify", "Push back"]
docs:        ["Summarize", "Expand", "Rewrite"]
other:       ["Confirm", "Clarify", "Decline"]
```

Missing API key is not a fallback condition; the capsule shows a readable setup error.

### Capsule UI

Update `ProductReplyCapsuleView`:

1. Initial render: `Drafting moves...` while chips are being requested.
2. Chips state: three pill buttons in a row, with `1` `2` `3` keyboard pick.
3. Pick state: `Expanding...` while expansion runs.
4. Editing state: editable draft, with `Cmd+R` re-running expansion from the current edit.
5. `Tab` cycles to the next chip and re-runs expansion.
6. `Esc` closes.
7. `Enter` pastes.

### Wiring

`SelectionCaptureService` returns the bundle and one compressed screenshot attachment. `ReplyCapsuleController` calls `GenerationService.chips(...)` immediately after capture, then `expand(...)` on pick.

### Config

API key resolution order:

1. `OPENAI_API_KEY` env var
2. `casprflow.config.local.json` in the project root -> `openai_api_key`
3. `~/Library/Application Support/CasprFlow/config.json` -> `openai_api_key`

Model resolution order:

1. `OPENAI_MODEL` env var
2. `casprflow.config.local.json` in the project root -> `openai_model`
3. `~/Library/Application Support/CasprFlow/config.json` -> `openai_model`
4. `gpt-5.4-nano`

Latency config:

- `openai_reasoning_effort` defaults to `low`; stale `minimal` config values are normalized to `low`
- `openai_image_detail` defaults to `high`

User profile config:

- `user_name` identifies the local user, for example `Daksh`
- `user_style` describes reply style
- `work_context` gives lightweight local project/work context

Missing key -> capsule shows readable error and offers `Esc`.

## Non-Goals

- no settings UI
- no model picker
- no streaming
- no learning yet (Phase 6)
- no OCR text in generation prompts

## Deliverables

- `GenerationService` + `MockGenerationService`
- chip + expansion prompt builders
- updated `ProductReplyCapsuleView`
- `PhaseFiveSelfCheck` with mock-backed coverage
- screenshot + AX path into OpenAI Responses image input
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
- OpenAI request uses Responses text + image content
- mock service round-trips chips and expansion

## Manual Checks

With `OPENAI_API_KEY` set:

- Slack reply field -> press hotkey -> see three chat-style chips -> press `1` -> see one expansion -> `Enter` pastes.
- iMessage reply field -> see casual chips -> pick one -> expansion is short and casual.
- Code editor with a prompt box -> see code-style chips -> pick `Implement` -> expansion is imperative.
- Confirm the debug label says screenshot + AX and expansion uses the current visible context.

Without an API key:

- Confirm error state is readable and `Esc` closes.

## Exit Criteria

- chips appear within ~800 ms when OpenAI is fast
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

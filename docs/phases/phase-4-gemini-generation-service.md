# Phase 4: Gemini Generation Service

## Outcome

Selected text produces one real Gemini reply when an API key is available, while tests remain deterministic without network access.

## Scope

- Add `GenerationService`.
- Use `URLSession`.
- Use Gemini `generateContent`.
- Default model: `gemini-3-flash-preview`.
- Read API key from `GEMINI_API_KEY` or local developer configuration.
- Keep API key out of git.
- Add a mock generation mode for tests.
- Add prompt construction.
- Parse response into plain reply text.
- Show loading and error states in the capsule.
- Preserve stub generator only as test/dev fallback if useful.

## Gemini API Shape

Use the official Gemini REST shape:

- endpoint: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- header: `x-goog-api-key: {GEMINI_API_KEY}`
- JSON input: `contents[].parts[].text`
- optional REST system instruction: `system_instruction.parts[].text`

## Deliverables

- Live Gemini generation service.
- Mock generation service.
- Prompt builder.
- Basic local config documentation in phase report.
- `docs/phase-reports/phase-4-gemini-generation-service.md`

## Automated Checks

- `make build`
- `make test`

Recommended unit coverage:

- prompt includes selected message
- prompt includes learned preferences when provided
- prompt asks for one reply only
- request builder uses `GEMINI_API_KEY`
- response parser extracts plain text from Gemini candidates
- missing API key produces controlled error

## Manual Checks

With `GEMINI_API_KEY` available:

- Highlight a message in Notes.
- Press `Option + Space`.
- Confirm capsule shows loading quickly.
- Confirm one generated reply appears.
- Confirm no markdown, no quotes, no alternatives.
- Press `Escape`.

Without `GEMINI_API_KEY`:

- Confirm app shows a readable error and does not crash.

## Exit Criteria

- Live Gemini generation works with an API key.
- Tests do not depend on network.
- The app still works through Phase 3 behavior except reply text is real.
- No OpenAI product API remains in the app.

## Stop If

- API key handling would require building a settings screen.
- Network errors crash the app.
- Generation returns multi-option output and prompt cleanup cannot contain it.
- Any product path still calls OpenAI.

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-5-local-learning-store.md. Complete only that phase, run its checks, write the phase report, and stop.
```

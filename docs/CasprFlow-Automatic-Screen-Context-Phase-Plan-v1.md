# CasprFlow Automatic Screen Context Intermediary Plan
### Fast current-window context for the next reply

## Intent

This is not a product pivot and not a new product surface.

This is an intermediary implementation phase that changes how CasprFlow gathers reply context:

```text
before: user must select message text
after: user focuses the reply field, presses Option + Space, and CasprFlow gathers enough current-screen context automatically
```

The product goal stays the same:

```text
Option + Space -> tiny reply capsule -> edit/regenerate -> Enter paste -> learn locally
```

The context goal changes:

```text
collect as much useful current-window context as possible, prune it aggressively, and send only what is necessary to Gemini for the most probable response
```

## Core Principle

The experience must feel nearly instant.

That means:

- no continuous screen recording
- no always-on OCR
- no screenshot-to-Gemini by default
- no large context dump in normal generation
- no heavy choice UI
- no extra prompt box
- no mandatory text selection

The system can collect broad raw context locally, but the model should receive a small, ranked, prompt-ready context.

## Context Stack

Use this order:

```text
Primary: macOS Accessibility tree + active app/window/focused field
Secondary: local OCR from active-window screenshot
Optional: one screenshot to Gemini only when AX+OCR confidence is low
```

The default Gemini request should be text-only.

## Target User Flow

```text
1. User clicks/focuses the reply field.
2. User presses Option + Space.
3. CasprFlow snapshots current app/window context.
4. CasprFlow extracts AX text immediately.
5. CasprFlow runs local OCR only if AX context is weak or incomplete.
6. CasprFlow fuses and prunes context into a compact prompt.
7. Gemini returns one most likely reply.
8. Capsule appears with the reply focused and editable.
9. Optional nudge chips are available for fast steering.
10. Enter pastes into the already-focused reply field.
```

Selection may still work as a precision override during development, but it should not be required for the happy path.

## Latency Budget

Target perceived latency:

```text
hotkey -> capsule shell: under 100 ms
hotkey -> first useful draft: under 800-1200 ms when Gemini is fast
```

Implementation budget:

- show capsule immediately with `Drafting...`
- AX capture: target under 100 ms
- local OCR: target under 300 ms, only when useful
- context fusion/pruning: target under 50 ms
- Gemini request: single request, short output
- screenshot fallback: never in the fast path unless confidence is low

If OCR is still running, the app can start with AX context and only wait for OCR when AX confidence is poor.

## Context Collection

Collect broad context locally:

- active app name
- bundle identifier
- process id
- active window title
- focused field role/subrole
- focused field value if exposed
- whether focused field likely accepts text
- nearby AX text candidates
- visible AX tree text candidates
- active-window screenshot metadata
- OCR text candidates when needed
- optional selected text if present

Do not send all of this to Gemini.

## Context Pruning

Build a ranked `PromptContext` from the raw capture.

Keep:

- app name
- window/channel/document title
- focused field summary
- likely recent message text
- nearby surrounding visible text
- selected text if present
- 1-3 highest-signal OCR blocks when AX misses content

Drop:

- repeated toolbar labels
- menu items
- button chrome
- sidebar noise
- duplicated AX/OCR lines
- long raw AX trees
- long full element dumps
- invisible/debug-only metadata

Prompt budget:

```text
metadata: under 200 tokens
visible conversation/context: under 900 tokens
style/learning later: under 150 tokens
reply output: under 80 words
```

## Confidence

Use a deterministic confidence score. No ML needed.

High confidence:

- focused text input exists
- app/window title is meaningful
- AX or OCR found readable non-chrome text
- context looks message-like or document-like
- prompt context is concise

Low confidence:

- only toolbar/menu text is found
- no focused input exists
- OCR is empty or garbage
- AX text is mostly buttons/icons
- too much duplicated or unrelated text

Suggested behavior:

```text
0.70+ -> send compact text context to Gemini
0.40-0.69 -> send compact text context with "context may be partial"
below 0.40 -> either ask for more visible context or use screenshot fallback if enabled
```

## Gemini Request Shape

Default request should be one short text-only call:

```text
You write one reply the user can paste into the currently focused app.
Do not explain.
Do not include alternatives.
Keep it natural and concise.

App:
{app}

Window:
{window}

Focused field:
{focused_field_summary}

Visible context:
{ranked_prompt_context}

Write the most likely reply.
```

Return one draft by default. The main UI should still feel decisive.

## Optional Nudge UI

Avoid showing three full replies by default. That turns the product into a chooser and slows the user down.

Instead, use one main draft plus tiny nudge chips:

```text
[warmer] [more direct] [shorter]
```

or, when the content clearly has multiple possible endings:

```text
[confirm] [ask follow-up] [decline softly]
```

Nudge behavior:

- no prompt box
- one click or keyboard shortcut
- regenerates the same draft intent with a small steering instruction
- keeps the edited draft as context if the user changed it
- does not create a big multi-option UI

Phase implementation can start with hidden or debug-only nudge chips. Do not block the core flow on them.

## Intermediary Phase Plan

### Phase 3A: Fast Context Contract

Outcome:

CasprFlow has a raw context model and a compact prompt context model.

Scope:

- Add `RawScreenContext`.
- Add `PromptContext`.
- Add `contextConfidence`.
- Add `captureMode`.
- Add debug inspector sections:
  - raw AX candidates
  - final prompt context
  - confidence
  - dropped/noisy candidate count
- Keep current stub/product capsule working.

Done when:

- Debug inspector shows exactly what would be sent to Gemini.
- No OCR or screenshot fallback yet.

### Phase 3B: AX-First Automatic Context

Outcome:

Without selecting text, pressing `Option + Space` can produce useful prompt context from AX.

Scope:

- Use active app/window/focused field.
- Walk visible AX tree.
- Rank text candidates.
- Detect whether focused field likely accepts text.
- Use selected text only as an optional high-confidence candidate.
- Do not require selection.

Done when:

- User can focus the reply field in Notes/browser, press `Option + Space`, and see prompt context without selecting text.

### Phase 3C: Local OCR Assist

Outcome:

When AX context is weak, local OCR improves prompt context.

Scope:

- Capture active window only on hotkey.
- Use Apple's Vision OCR locally.
- Run OCR only when AX confidence is below threshold or debug mode requests it.
- Add OCR candidates to debug inspector.
- Do not store screenshots.
- Do not send screenshots to Gemini.

Done when:

- OCR text appears in debug inspector and can contribute to `PromptContext`.

### Phase 3D: Fast Stub Reply From Prompt Context

Outcome:

The non-AI loop uses automatic context instead of mandatory selection.

Scope:

- Stub generator uses `PromptContext`.
- User starts with cursor in reply field.
- `Enter` pastes into the focused field.
- Avoid replacing selected/source text by making no-selection the default flow.

Done when:

```text
focus reply field -> Option + Space -> stub draft -> edit/regenerate -> Enter paste
```

works in Notes.

### Phase 4: Gemini Text Generation

Outcome:

Gemini generates one reply from compact prompt context.

Scope:

- One text-only Gemini request by default.
- Short output.
- No screenshot input by default.
- Debug inspector shows exact prompt context.
- Product capsule shows one editable draft.

Done when:

- The visible current-window context becomes one useful Gemini reply without selected text.

### Phase 4B: Nudge Chips

Outcome:

The user can steer the draft with minimal input.

Scope:

- Add 2-3 small nudge chips.
- Suggested initial chips:
  - `shorter`
  - `warmer`
  - `more direct`
- Optional contextual chips later:
  - `confirm`
  - `ask follow-up`
  - `decline softly`
- Regenerate one draft, not a list of full alternatives.

Done when:

- User can adjust the draft without typing a prompt.

### Phase 4C: Screenshot Fallback Gate

Outcome:

If AX+OCR context is low confidence, one active-window screenshot can be attached to Gemini.

Scope:

- Feature flag controlled.
- Low/medium media resolution first.
- Attach screenshot only below confidence threshold.
- No screenshot persistence.
- Debug inspector clearly marks fallback use.

Done when:

- Custom-rendered or OCR-poor screens have one optional recovery path without making vision calls the default.

## What To Avoid

Avoid:

- three full replies shown by default
- big overlays
- chat-like prompt boxes
- manual context picking
- continuous screenshots
- raw screenshot send on every hotkey
- storing screen images
- app-specific integrations
- overfitting to Slack/Notes too early

## Best Effective Outcome

The best MVP outcome is not "capture everything and send everything."

The best outcome is:

```text
capture broadly locally
rank aggressively
send compact context
show one draft fast
offer tiny nudges only if needed
paste with one key
```

This keeps CasprFlow fast, low-friction, cheap to run, and still materially more intelligent than selection-only context.

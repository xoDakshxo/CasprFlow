# Knowledge Fast Replies MVP Scope

Status: Planning source of truth for the OpenAI/local-knowledge MVP.

This folder defines the linear implementation path for a robust CasprFlow MVP that gives fast replies, learns from the user's edits, and uses local knowledge without adding a second runtime or external agent framework.

## Product Goal

When the user presses `Option + Space` in a real app, CasprFlow should:

1. capture the active reply context without mutating the clipboard
2. build the smallest useful context packet from AX, focused screenshot crop, and local metadata
3. call a screenshot/context pre-parser that returns a compact `ContextBrief`
4. retrieve local knowledge about the user's style, app, people, projects, and recent behavior
5. call an output planner that returns three intent chips and three expanded drafts
6. show the default draft while letting the user switch chips without another model call
7. paste only when the user presses `Enter`
8. learn from the final pasted text
9. make the next reply measurably more personal

The MVP is done only when this loop works manually in real apps.

## Non-Negotiables

- Native macOS app stays Swift, SwiftUI, and AppKit.
- Fixed `Option + Space` hotkey.
- No hotkey picker.
- No browser extension.
- No account system.
- No sync.
- No dashboard.
- No auto-send.
- No clipboard-based context capture.
- No raw screenshot persistence by default.
- No external agent framework in the MVP path.
- OpenAI API key is the generation credential.
- Local knowledge and learning remain on disk under Application Support.

## Provider Scope

Use OpenAI Responses API for the MVP hot path.

Default target:

- context model: fast vision-capable model whose only job is screenshot/context analysis
- output model: strongest fast model for the first user-facing drafts
- edit/regenerate model: smaller fast model, because it receives the selected draft plus a narrow user instruction
- `store: false`
- strict structured output for both context parsing and reply planning
- low or no reasoning effort for latency
- tiny context-parser token limit
- tight output-planner token limit, but large enough for three concise drafts

The MVP should keep provider wiring isolated behind protocols so future providers can be added without changing capture, UI, paste, or learning code.

## Hot Path Shape

The hot path is allowed exactly two remote model calls:

```text
Option+Space
  -> CapturePackBuilder
  -> OpenAIContextBuilder
  -> LocalKnowledgeRetriever
  -> OpenAIOutputPlanner
  -> ReplyCapsuleView
  -> PasteService
  -> LearningEventStore
```

Anything slower than this belongs after paste or in idle time.

## Model Call Policy

The first pass is a two-call pipeline.

### Call 1: build-context

The context call is screenshot-aware and tightly constrained. It receives the focused screenshot crop plus compact AX metadata and returns only `ContextBrief`.

It must not write replies, chips, drafts, or user-facing text.

It should identify:

- active surface and app role
- latest reply target
- visible speakers or actors, only when visible or strongly implied
- current user position, such as input box, outgoing bubble, selected text, or active thread
- relevant visible messages/tasks
- ignored UI/chrome
- confidence and missing-context flags

The context output should be small enough to make call 2 mostly text-only.

### Call 2: build-output

The output call is the quality-critical user-facing call. It receives `CapturePack`, `ContextBrief`, and `KnowledgeContext`, then returns:

- target summary
- three chips
- one concise expanded draft for each chip
- default chip id
- learned label, if local knowledge was used

The output call should not receive the raw screenshot by default. It should use the screenshot-derived `ContextBrief` unless Phase 7 proves this hurts quality.

Chip selection after the first pass is local. Picking chip 1/2/3 swaps to the already returned draft and must not call the model.

Follow-up calls are allowed only after the first answer exists:

- custom input bar: user writes a specific instruction, then the strong output model may produce a custom draft from the existing `ContextBrief`, selected/active draft, local knowledge, and instruction
- edit regenerate: user edits the draft or asks for a change, then a smaller fast model rewrites only the selected draft
- retry after context failure: rerun build-context, then build-output if context succeeds
- retry after output failure: reuse the existing `ContextBrief` and rerun build-output

This keeps the first impression smart, makes screenshot understanding explicit, and keeps repeated edits cheaper.

## Screenshot Parsing Policy

Use one remote screenshot pre-parser in the MVP hot path.

Rules:

- the pre-parser is `build-context`, not a general agent
- it receives at most one focused screenshot crop
- it may receive compact AX metadata and selected text
- it returns only structured context
- it does not produce chips or drafts
- it has a strict timeout and fallback path
- it never stores screenshots
- it is skipped only when there is no screenshot and AX confidence is already high enough

The parser exists because better context is more important than saving one call. The token and latency budget are controlled by making its output small and reusable.

Do not add a third remote call in the MVP. If build-context is weak, improve the focused crop and schema before adding another model step.

## MVP Data Contracts

### CapturePack

`CapturePack` is the compact input to generation. It is built from the existing `ScreenContextBundle`, screenshot attachment, and local heuristics.

Required fields:

- capture id
- captured at
- app name
- bundle id
- window title
- surface kind
- focused field role/kind/value summary
- selected text, if AX exposes it
- recent message blocks from local grouping
- ambient context, capped
- visible AX candidates, pruned and redacted
- screenshot metadata
- optional screenshot attachment
- confidence score
- reason screenshot was or was not attached

### KnowledgeContext

`KnowledgeContext` is retrieved locally before generation.

Required fields:

- strongest global style signal
- app-specific style signal
- person-specific tone signal, if known
- project/thread hints, if known
- recent selected chips
- retrieval source ids

The MVP can start with JSON storage, but the contract should not depend on JSON. SQLite can replace it later.

### ContextBrief

`ContextBrief` is the build-context output.

Required fields:

- active surface kind
- reply target summary
- target confidence
- visible relevant messages or task snippets
- speaker/actor hints
- whether the latest visible content is incoming, outgoing, selected, or ambiguous
- ignored UI/chrome summary
- missing context flags
- screenshot confidence
- source ids from the `CapturePack`

### ReplyPlan

`ReplyPlan` is the build-output result.

Required fields:

- target summary
- target confidence
- surface kind
- context brief id
- three chips
- default chip id
- draft for each chip
- optional custom draft only after user writes a custom instruction
- learned label to show
- warnings/fallback reason

The UI should render from `ReplyPlan` and not know how the model was called.

### LearningEvent

`LearningEvent` is written after paste.

Required fields:

- capture id
- app name
- bundle id
- surface kind
- target summary
- chip shown
- chip selected
- draft shown
- generated draft
- final pasted text
- edit delta summary
- inferred signals
- created at

## Latency Targets

These are practical targets, not promises.

- capture pack built: under 200 ms
- first capsule response with fallback chips: under 300 ms
- build-context screenshot parse p50: under 800 ms
- build-output three-draft plan p50: under 1200 ms
- full two-call plan p50: under 2200 ms
- chip switching after plan returns: instant/local
- smaller edit/regenerate call p50: under 800 ms
- no UI hang while the model call runs

Sub-500 ms final text is not dependable with two remote calls. The MVP should optimize perceived speed with immediate fallback chips, visible context-building/output-building states, reusable `ContextBrief`, and local chip switching.

## Robustness Requirements

Every phase must keep the app usable when something fails:

- missing Accessibility permission
- missing Screen Recording permission
- missing OpenAI API key
- build-context timeout
- build-output timeout
- malformed `ContextBrief`
- malformed `ReplyPlan`
- no screenshot available
- no AX text available
- local learning file corrupt
- paste target disappeared

Fallbacks must be visible and testable.

## Privacy Requirements

- Do not store raw screenshots unless an explicit debug flag is enabled.
- Do not send local OCR text as bulk prompt context unless a phase explicitly implements redaction and caps.
- Do not send the raw screenshot to build-output by default; use the `ContextBrief`.
- Redact obvious secrets from AX candidates before model calls.
- Keep learning data local.
- Provide a clear learning reset path.
- Paste only; never send.

## Manual MVP Definition Of Done

The full MVP is done when the user can manually verify all of this:

1. In Slack or a work chat, `Option + Space` shows relevant chips and a concise work-style draft.
2. In Messages, `Option + Space` shows casual chips and a short human draft.
3. In a code/agent prompt box, `Option + Space` shows agentic chips and an implementation-ready prompt.
4. The debug view shows a compact `ContextBrief` that correctly identifies the reply target.
5. Switching among the three chips swaps drafts locally after the output plan returns.
6. Typing in the custom input bar can produce a custom draft without losing the original plan.
7. Editing or regenerating uses the smaller follow-up path.
8. Editing the generated draft and pressing `Enter` pastes into the original field.
9. A later invocation uses the learned style signal from the edit.
10. Clearing learning removes the learned label and stops applying the signal.
11. Missing API key and network timeout show recoverable UI states.
12. The app does not mutate the user's clipboard during capture.

## Folder Rules

- Execute phases in numeric order.
- Do not implement a later phase's behavior before its phase.
- Each phase must end with a manual test that the user can run in a real app.
- Each phase writes a report under `docs/knowledge-fast-replies-mvp/reports/`.
- A phase can leave extension points for future work, but must not claim future behavior works.
- If a phase changes product scope, update this `scope.md` in the same change.

# Phase 1: Capture Pack

## Outcome

Every hotkey capture can produce a compact `CapturePack` from the current `ScreenContextBundle`, including a clear decision about whether a screenshot is attached.

## Why This Comes Now

Fast replies depend on sending less context, not more. Before changing generation, we need one small, inspectable input packet.

## Scope

Implement local capture shaping only:

- `CapturePackBuilder`
- AX candidate pruning
- basic secret redaction
- screenshot attachment gate
- capture debug summary

Do not change the OpenAI prompt or capsule flow yet.

## Implementation Steps

1. Add `CapturePackBuilder` under `Sources/CasprFlowCore/`.
2. Build `CapturePack` from `ScreenContextBundle` plus `[ScreenshotAttachment]`.
3. Include selected text first when available.
4. Include recent message blocks with a strict count and character cap.
5. Include focused field value only after redaction and capping.
6. Prune chrome strings such as buttons, timestamps, channel nav, URLs, and tiny labels.
7. Redact obvious secrets:
   - API keys
   - tokens
   - long bearer strings
   - passwords in `key=value` or `key: value` shapes
8. Add a screenshot policy:
   - attach no image when text confidence is high
   - attach one focused/cursor crop when text confidence is low
   - never attach more than one screenshot in MVP
9. Record `screenshotDecision` in the pack for debugging.
10. Add self-checks for chat, Messages/casual, and code/editor surfaces.
11. Write the phase report.

## Automated Checks

- `make build`
- `make test`

Focused checks should prove:

- high-confidence selected text does not require screenshot.
- low-confidence chat context attaches at most one screenshot.
- redaction removes obvious API key shapes.
- AX chrome strings are pruned.
- pack JSON stays below the agreed character budget for fixtures.

## Manual Test

Use the debug inspector:

1. Launch the app.
2. Put the cursor in a Slack or chat reply field.
3. Press `Option + Space`.
4. Confirm the debug view shows a compact capture summary.
5. Confirm the chosen screenshot source is focused/cursor/visible fallback, not random UI.
6. Repeat in a code prompt box.

## Exit Condition

The user can manually inspect the capture summary and confirm CasprFlow is collecting the right focused context before generation changes.

## Stop If

- Capture requires clipboard mutation.
- More than one screenshot is needed to make the test pass.
- The debug view cannot explain why screenshot was attached or skipped.

## Not Yet Implemented

- no reply plan generation
- no local knowledge lookup
- no new capsule rendering
- no learning from edits


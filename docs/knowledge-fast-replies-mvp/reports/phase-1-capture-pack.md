# Phase 1 Report: Capture Pack

Status: Implemented, manual debug smoke pending

## Summary

- What changed:
  - Added `CapturePackBuilder`.
  - Added compact capture shaping from `ScreenContextBundle` and screenshot attachments.
  - Added pruning for chrome-like AX strings.
  - Added redaction for obvious secret/token/password/API-key shapes.
  - Added screenshot attachment policy:
    - skip image when text confidence is high enough
    - attach one screenshot when confidence is low and an attachment exists
    - mark screenshot unavailable when confidence is low and no image exists
  - Added compact `CapturePack.debugJSON` that reports image byte count without dumping raw image data.
  - Added a `Capture Pack` section to the debug inspector.
  - Added a screenshot preview inside the debug inspector when the pack attaches an image.
  - Tightened Slack chrome pruning for channel/window titles, search rows, thread labels, and truncated nav text.
  - Added Phase 1 self-checks and wired them into `CasprFlowChecks`.
- What now works:
  - A capture pack can be built locally from the current bundle.
  - The debug inspector shows the exact pack shape, screenshot decision, counts, metadata, and compact JSON.
  - High-confidence selected text skips screenshot attachment.
  - Low-confidence context attaches at most one screenshot.
  - Obvious secrets are redacted before pack output.
  - Chrome-like AX strings are pruned.
  - Slack channel chrome from the observed debug sample no longer becomes recent context.
- What was intentionally skipped:
  - No `build-context` OpenAI call.
  - No `build-output` OpenAI call.
  - No local knowledge retrieval.
  - No capsule behavior change beyond debug inspector visibility.
  - No learning behavior.

## Checks

- Build:
  - Passed: `make build`
  - Note: the app bundle was rebuilt and re-signed, so macOS may require Accessibility permission to be granted again before hotkey smoke testing.
- Unit tests:
  - Passed: `make test`
  - `CasprFlowChecks` now covers screenshot skip/attach policy, redaction, chrome pruning, Slack chrome pruning, and compact debug JSON.
- Manual smoke:
  - Not run in this agent session.
  - Required local smoke:
    - Launch `.build/CasprFlow.app`.
    - Put the cursor in Slack or another chat reply field.
    - Press `Option + Space`.
    - Confirm the debug inspector shows `Capture Pack`.
    - Confirm `Screenshot decision` explains attached/skipped/unavailable.
    - Confirm `Screenshot source` is focused/cursor/visible fallback when attached.
    - Confirm the screenshot preview renders in the `Capture Pack` section.
    - Confirm Slack channel title/search/thread chrome does not dominate `recent`.
    - Repeat in a code prompt box.
- Docs/skills:
  - Phase stayed within scope: local capture shaping and debug visibility only.

## Evidence

- Commands run:
  - `make build`
  - `make test`
- Apps tested:
  - None manually in this run.
- Files changed:
  - `Sources/CasprFlowCore/CapturePackBuilder.swift`
  - `Sources/CasprFlowCore/KnowledgeFastRepliesPhaseOneSelfCheck.swift`
  - `Sources/CasprFlowCore/ReplyPlanningModels.swift`
  - `Sources/CasprFlowCore/KnowledgeFastRepliesPhaseZeroSelfCheck.swift`
  - `Sources/CasprFlowCore/ReplyCapsuleController.swift`
  - `Sources/CasprFlowChecks/main.swift`
  - `docs/knowledge-fast-replies-mvp/reports/phase-1-capture-pack.md`

## Known Issues

- Manual debug-window validation is pending because it requires local GUI interaction and may require re-granting Accessibility after the app bundle was re-signed.

## Next Phase Prompt

Use the repo-local CasprFlow skills and execute `docs/knowledge-fast-replies-mvp/phases/phase-2-two-call-context-and-output.md`. Complete only that phase, run its checks, write the phase report, and stop.

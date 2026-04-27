# Phase 2 Report: Two-Call Context And Output

Status: Implemented, manual API smoke pending

## Summary

- What changed:
  - Added `OpenAIContextBuilder` for the screenshot-aware build-context call.
  - Added `OpenAIOutputPlanner` for the build-output call that returns three chips and one draft per chip.
  - Added separate model routing for context, output, and follow-up roles.
  - Reused the existing Responses API client with per-call instructions.
  - Added strict JSON schemas for `ContextBrief` and `ReplyPlan`.
  - Added safe fallback parsing for malformed context and reply-plan outputs.
  - Loaded API key, model roles, reasoning effort, and image detail from env vars plus the existing developer config paths.
  - Added Phase 2 self-checks and wired them into `CasprFlowChecks`.
- What now works:
  - `build-context` sends compact `CapturePack` metadata plus at most one focused screenshot.
  - `build-context` is explicitly prohibited from producing chips, drafts, or user-facing replies.
  - `build-output` receives `CapturePack`, `ContextBrief`, and empty `KnowledgeContext`.
  - `build-output` sends no screenshot by default.
  - Both calls use `store: false`.
  - Malformed outputs fall back without crashing the capsule path.
- What was intentionally skipped:
  - No fast hydrated capsule UI yet.
  - No local chip-to-draft switching UI yet.
  - No custom follow-up route yet.
  - No local learning retrieval.
  - No persisted learning event.

## Checks

- Build:
  - Passed: `make build`
  - Note: the app bundle was rebuilt and re-signed, so macOS may require Accessibility permission to be granted again before hotkey smoke testing.
- Unit tests:
  - Passed: `make test`
  - `CasprFlowChecks` now covers request shape, screenshot routing, no-reply context prompting, store policy, malformed output fallback, duplicate chip fallback, missing draft fallback, and distinct model roles.
- Manual smoke:
  - Not run in this agent session.
  - Required local smoke:
    - Ensure `OPENAI_API_KEY` or `openai_api_key` is configured.
    - Launch `.build/CasprFlow.app`.
    - Put the cursor in Slack/work chat and press `Option + Space`.
    - Confirm the debug inspector still shows `Capture Pack` and screenshot preview when attached.
    - Confirm Phase 3 wiring shows `ContextBrief` and `ReplyPlan` in the capsule/debug flow.
    - Repeat in Messages or another casual text surface.
    - Repeat in a code/agent prompt box.
- Docs/skills:
  - Phase stayed within scope: service-level two-call planning only.

## Evidence

- Commands run:
  - `make build`
  - `make test`
- Apps tested:
  - None manually in this run.
- Files changed:
  - `Sources/CasprFlowCore/OpenAIPlanningServices.swift`
  - `Sources/CasprFlowCore/KnowledgeFastRepliesPhaseTwoSelfCheck.swift`
  - `Sources/CasprFlowCore/GenerationService.swift`
  - `Sources/CasprFlowChecks/main.swift`
  - `docs/knowledge-fast-replies-mvp/reports/phase-2-two-call-context-and-output.md`

## Known Issues

- Manual OpenAI smoke testing is pending.
- `ReplyCapsuleController` still uses the old sequential chip/expand UI path until Phase 3 wires the new `ReplyPlan` flow into the capsule.

## Next Phase Prompt

Use the repo-local CasprFlow skills and execute `docs/knowledge-fast-replies-mvp/phases/phase-3-fast-capsule-flow.md`. Complete only that phase, run its checks, write the phase report, and stop.

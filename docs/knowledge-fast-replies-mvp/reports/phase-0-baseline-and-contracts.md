# Phase 0 Report: Baseline And Contracts

Status: Implemented, manual smoke pending

## Summary

- What changed:
  - Added typed contracts for the knowledge fast replies path:
    - `CapturePack`
    - `ContextBrief`
    - `KnowledgeContext`
    - `ReplyPlan`
    - `ReplyPlanChip`
    - `ReplyPlanDraft`
    - `LearningEvent`
    - `ContextBuilding`
    - `OutputPlanning`
  - Added `ReplyPlan` validation so plans require exactly three chips, a valid default chip, and one non-empty draft per chip.
  - Added Phase 0 self-checks for JSON round-tripping and contract invariants.
  - Hooked the new self-checks into `CasprFlowChecks`.
- What now works:
  - The new MVP path has stable data contracts without changing hotkey, capsule, generation, paste, or learning behavior.
  - `ContextBrief` can represent selected, incoming, outgoing, and ambiguous targets.
  - `CapturePack` can represent chat, casual, and code surfaces.
  - Empty `KnowledgeContext` is valid for Phase 2.
  - `LearningEvent` stores generated and final text separately.
- What was intentionally skipped:
  - No compact capture pack builder.
  - No `build-context` implementation.
  - No `build-output` implementation.
  - No UI wiring.
  - No local knowledge retrieval.
  - No new learning behavior.

## Checks

- Build:
  - Passed: `make build`
  - Note: the app bundle was rebuilt and re-signed, so macOS may require Accessibility permission to be granted again before hotkey smoke testing.
- Unit tests:
  - Passed: `make test`
  - `CasprFlowChecks` now includes Phase 0 contract coverage.
- Manual smoke:
  - Not run in this agent session.
  - Required local smoke:
    - Launch `.build/CasprFlow.app`.
    - Put the cursor in Notes or another simple text field.
    - Press `Option + Space`.
    - Confirm the existing capsule behavior still appears.
    - Press `Esc` to close.
- Docs/skills:
  - Phase stayed within scope: contracts only, no runtime behavior changes.

## Evidence

- Starting state:
  - Branch: `codex/knowledge-fast-replies-mvp`
  - `git status --short`: `?? docs/knowledge-fast-replies-mvp/`
- Commands run:
  - `git status --short`
  - `git branch --show-current`
  - `make build`
  - `make test`
- Apps tested:
  - None manually in this run.
- Files changed:
  - `Sources/CasprFlowCore/ReplyPlanningModels.swift`
  - `Sources/CasprFlowCore/KnowledgeFastRepliesPhaseZeroSelfCheck.swift`
  - `Sources/CasprFlowChecks/main.swift`
  - `docs/knowledge-fast-replies-mvp/reports/phase-0-baseline-and-contracts.md`

## Known Issues

- Manual hotkey smoke is pending because it requires local GUI interaction and may require re-granting Accessibility after the app bundle was re-signed.

## Next Phase Prompt

Use the repo-local CasprFlow skills and execute `docs/knowledge-fast-replies-mvp/phases/phase-1-capture-pack.md`. Complete only that phase, run its checks, write the phase report, and stop.

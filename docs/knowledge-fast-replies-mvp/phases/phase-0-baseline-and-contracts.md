# Phase 0: Baseline And Contracts

## Outcome

The branch has a verified baseline and typed contracts for the new MVP path, but no user-visible behavior changes yet.

## Why This Comes First

The app already has capture, chips, expansion, paste, and permission work. This phase prevents the new MVP from becoming a rewrite by defining contracts around the current system first.

## Scope

Add pure data types and tests only:

- `CapturePack`
- `ContextBrief`
- `KnowledgeContext`
- `ReplyPlan`
- `ReplyPlanChip`
- `ReplyPlanDraft`
- `LearningEvent`
- `ContextBuilding` protocol
- `OutputPlanning` protocol

Do not change hotkey behavior, capsule UI, OpenAI request behavior, paste behavior, or learning behavior in this phase.

## Implementation Steps

1. Run `git status --short` and record the starting state in the phase report.
2. Read current `ScreenContextBundle`, `GenerationService`, and `ReplyCapsuleController` call boundaries.
3. Add a new source file for the MVP contracts, likely `Sources/CasprFlowCore/ReplyPlanningModels.swift`.
4. Make the types `Codable`, `Equatable`, and `Sendable` where practical.
5. Keep fields optional only when they are genuinely unavailable in Phase 0.
6. Add helper fixtures for a chat capture, casual capture, and code capture.
7. Add self-check coverage that encodes and decodes each contract.
8. Add `ContextBuilding` and `OutputPlanning` protocols but do not wire them into the UI yet.
9. Write `docs/knowledge-fast-replies-mvp/reports/phase-0-baseline-and-contracts.md`.

## Automated Checks

- `make build`
- `make test`

Focused checks should prove:

- `ReplyPlan` with three chips round-trips through JSON.
- `ReplyPlan` requires one draft per chip.
- `ContextBrief` can represent selected, incoming, outgoing, and ambiguous targets.
- `CapturePack` can represent chat, casual, and code surfaces.
- `KnowledgeContext` can be empty without crashing consumers.
- `LearningEvent` can represent generated and final text separately.

## Manual Test

Run the current app exactly as before:

1. Build and launch the app.
2. Put the cursor in Notes or another simple text field.
3. Press `Option + Space`.
4. Confirm the existing capsule behavior still appears.
5. Press `Esc` to close.

## Exit Condition

The user can manually confirm that current hotkey/capsule behavior is unchanged, and the new contracts exist with passing tests.

## Stop If

- A contract requires changing the current UI before Phase 3.
- Existing capture or paste behavior regresses.
- Tests need real OpenAI network access.

## Not Yet Implemented

- no compact capture pack builder
- no two-call context/output pipeline
- no local knowledge retrieval
- no new learning behavior
- no robustness changes

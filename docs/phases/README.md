# CasprFlow Phases
### Conductor-style execution tracker for the MVP

## MVP Target

**highlight message -> press `Option + Space` -> tiny reply capsule -> edit or regenerate -> paste -> learn locally**

Use this folder as the execution queue. Each phase is a separate file so Codex can run one phase, write its report, and stop.

Use `docs/phase-audits/` for audit and decision-record documents created by phases.

## Phase Index

| Phase | File | Result |
| --- | --- | --- |
| 0 | [phase-0-intake.md](phase-0-intake.md) | Implementation path chosen |
| 1 | [phase-1-native-walking-skeleton.md](phase-1-native-walking-skeleton.md) | Native app shell, fixed hotkey, placeholder capsule |
| 2 | [phase-2-selected-text-capture.md](phase-2-selected-text-capture.md) | Highlighted text reaches the app, product preview and debug inspector render |
| 3 | [phase-3-stub-reply-capsule-and-paste.md](phase-3-stub-reply-capsule-and-paste.md) | Full OS loop works without live AI |
| 4 | [phase-4-gemini-generation-service.md](phase-4-gemini-generation-service.md) | Selected text becomes one Gemini reply |
| 5 | [phase-5-local-learning-store.md](phase-5-local-learning-store.md) | Edits create visible local signals |
| 6 | [phase-6-regenerate-from-edit.md](phase-6-regenerate-from-edit.md) | User can steer reply with `Command + R` |
| 7 | [phase-7-mvp-hardening-and-demo-candidate.md](phase-7-mvp-hardening-and-demo-candidate.md) | Full MVP works twice in real apps |

## Planning Method

This phase system uses:

- walking skeleton first
- one usable increment per phase
- explicit Definition of Ready
- explicit Definition of Done
- testable acceptance criteria
- phase reports as evidence

References:

- Scrum Guide: https://scrumguides.org/scrum-guide.html
- Agile Alliance Definition of Ready: https://agilealliance.org/glossary/definition-of-ready/
- Agile Alliance INVEST: https://agilealliance.org/glossary/invest/
- Atlassian acceptance criteria: https://www.atlassian.com/work-management/project-management/acceptance-criteria
- Walking Skeleton: https://gaiwan.co/wiki/WalkingSkeleton.md
- Gemini API text generation: https://ai.google.dev/gemini-api/docs/text-generation

## How To Run A Phase

Use this prompt shape:

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-N-name.md. Complete only that phase, run its checks, write the phase report, and stop.
```

At the start of every phase:

1. Read `AGENTS.md`.
2. Read `.codex/skills/casprflow-mvp-build/SKILL.md`.
3. Read `.codex/skills/casprflow-macos-automation/SKILL.md` for OS-facing work.
4. Read `.codex/skills/casprflow-product-docs/SKILL.md` for docs or scope work.
5. Read this README.
6. Read the current phase file.
7. Inspect `git status --short`.

At the end of every phase:

1. Run the phase's automated checks.
2. Run the phase's manual smoke checks when the app exists.
3. Create or update the phase report under `docs/phase-reports/`.
4. State exactly what passed, what failed, and what remains.
5. Stop. Do not start the next phase unless asked.

## Global Definition Of Ready

A phase is ready only when:

- The previous phase report exists and is marked `Passed`, or this is Phase 0.
- `git status --short` has been inspected.
- The current phase has a single clear outcome.
- Required secrets, network access, or macOS permissions are available or explicitly marked as blockers.
- The phase does not add non-MVP scope.

If any item is missing, Codex should either fix the missing setup inside the phase or stop with a blocker report.

## Global Definition Of Done

A phase is done only when:

- The phase deliverables exist.
- The app builds if app code exists.
- Unit tests pass if a test target exists.
- Manual checks are completed or blocked with a concrete reason.
- New behavior is documented in the phase report.
- No hotkey picker, auto-send, account system, sync, dashboard, browser extension, mobile app, embeddings, or fine-tuning was added.
- The final response includes the next phase prompt.

## Phase Report Template

Create reports in:

`docs/phase-reports/`

Use this shape:

```markdown
# Phase N Report: Name

Status: Passed | Blocked | Failed

## Summary

- What changed:
- What now works:
- What was intentionally skipped:

## Checks

- Build:
- Unit tests:
- Manual smoke:
- Docs/skills:

## Evidence

- Commands run:
- Apps tested:
- Files changed:

## Known Issues

- None, or list concrete issues.

## Next Phase Prompt

Use the repo-local CasprFlow skills and execute docs/phases/phase-N+1-name.md. Complete only that phase, run its checks, write the phase report, and stop.
```

## Non-Negotiables

- Fixed `Option + Space` hotkey.
- No hotkey picker.
- Gemini generation, not OpenAI.
- No auto-send.
- No large editor overlay.
- No app-specific integrations.
- No account system.
- No cloud memory.
- No model training.
- No phase can be marked passed without evidence.

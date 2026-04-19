# CasprFlow Phases

Conductor-style execution tracker. Each phase is one PR. Run one phase, write its report under `docs/phase-reports/`, stop.

## Phase Index

| # | File | Status | Outcome |
|---|---|---|---|
| 0 | [phase-0-intake.md](phase-0-intake.md) | Done | Source-reuse decision recorded |
| 1 | [phase-1-native-walking-skeleton.md](phase-1-native-walking-skeleton.md) | Done | App shell, hotkey, placeholder capsule |
| 2 | [phase-2-selected-text-capture.md](phase-2-selected-text-capture.md) | Done | AX selection + rich context, debug inspector |
| 3 | [phase-3-stub-reply-capsule-and-paste.md](phase-3-stub-reply-capsule-and-paste.md) | Done | Stub capsule, paste loop, AX+OCR prompt context |
| 4 | [phase-4-structured-context-bundle.md](phase-4-structured-context-bundle.md) | Done | Single `ScreenContextBundle`: surface kind, grouped OCR, JSON-shaped output, expanded debug UI |
| 5 | [phase-5-three-intent-chips.md](phase-5-three-intent-chips.md) | Done | OpenAI chip prompt + expansion prompt; replaces single-draft model |
| 5.5 | [phase-5-5-permiso-permissions-flow.md](phase-5-5-permiso-permissions-flow.md) | Done | Permiso-style drag/drop helpers for Accessibility and Screen Recording |
| 6 | [phase-6-local-learning.md](phase-6-local-learning.md) | Pending | Local JSON learning, edit signals, learned label |
| 7 | [phase-7-mvp-hardening-and-demo.md](phase-7-mvp-hardening-and-demo.md) | Pending | Real-app demo pass, error states, packaging notes |

Phases 4 and 5 together replace the previous generation + regenerate plan. Picking a chip is the regeneration loop — there is no separate regenerate step.

## How To Run A Phase

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-N-name.md.
Complete only that phase, run its checks, write the phase report, and stop.
```

Before starting: read `AGENTS.md`, `docs/CasprFlow-Product-Model-v1.md`, `docs/CasprFlow-Tech-Spec-v1.md`, this file, the phase file, and `git status --short`.

After finishing: run `make build` and `make test`, write the report, stop.

## Definition Of Ready

- previous phase report exists and is `Passed`, or this is Phase 0
- the phase has one clear outcome
- required permissions / API keys are available or noted as blockers
- the phase does not add non-MVP scope

## Definition Of Done

- deliverables exist
- `make build` and `make test` pass
- manual checks completed or blocked with a concrete reason
- the phase report is written under `docs/phase-reports/`
- no hotkey picker, auto-send, account system, sync, dashboard, browser extension, mobile app, embeddings, or fine-tuning was added
- the response includes the next phase prompt

## Phase Report Template

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

- fixed `Option + Space` hotkey, no picker
- OpenAI Responses API for generation, defaulting to `gpt-5.4-nano`
- no auto-send
- no large editor overlay
- no app-specific integrations
- no account system / cloud / training
- no phase passes without evidence

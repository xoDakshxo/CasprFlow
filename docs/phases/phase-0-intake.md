# Phase 0: Intake, Source Reuse, and Scaffold Decision

## Outcome

The repo has a confirmed implementation path before app code starts.

## Scope

- Inspect existing docs and repo-local skills.
- Decide whether to port from Axii immediately or implement the first shell locally.
- If network access is available, clone or inspect `bwarzecha/Axii` outside the source tree first.
- Identify exact source files or patterns worth porting.
- Confirm no non-Apache source is being ported.
- Fix any doc or skill contradictions before coding.
- Confirm Gemini is the generation provider.

## Deliverables

- `docs/phase-reports/phase-0-intake.md`
- Optional: `docs/phase-audits/source-reuse-audit-v1.md` if source reuse details are non-trivial.

## Automated Checks

- `rg -n "OpenAI|OPENAI|hotkey picker|auto-send|browser extension|mobile app|fine-tuning|embeddings" AGENTS.md docs .codex/skills`
- `git status --short`

Mentions of excluded scope are allowed only where they explicitly say not to build it. Mentions of OpenAI are allowed only for Codex metadata such as `agents/openai.yaml`, not product generation.

## Manual Checks

Confirm the phase plan, tech spec, MVP initiation doc, implementation plan, and skills all agree on:

- fixed `Option + Space`
- no hotkey picker
- reply capsule
- `Command + R` regenerate
- paste, never send
- local JSON learning
- Gemini generation

## Exit Criteria

- A clear go-forward decision exists:
  - "Port these Axii patterns now", or
  - "Build shell locally and use Axii as reference only."
- License handling is documented if source will be copied.
- Gemini API key handling is documented as `GEMINI_API_KEY` or local developer config.
- No app code is required yet.

## Stop If

- Axii license cannot be verified.
- Network access is needed and unavailable.
- The docs disagree about core MVP scope.
- The plan still references OpenAI as the product generation provider.

## Next Phase Prompt

```text
Use the repo-local CasprFlow skills and execute docs/phases/phase-1-native-walking-skeleton.md. Complete only that phase, run its checks, write the phase report, and stop.
```

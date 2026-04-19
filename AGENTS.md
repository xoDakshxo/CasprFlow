# CasprFlow Agent Instructions

## Read First (in this order)

1. `docs/CasprFlow-Concept-v1.md` — the original wedge.
2. `docs/CasprFlow-Product-Model-v1.md` — current interaction model: `context -> 3 chips -> pick -> expansion`.
3. `docs/CasprFlow-Tech-Spec-v1.md` — technical surface and bundle shape.
4. `docs/phases/README.md` — phase queue and execution rules.

`docs/phases/` is the execution source of truth. The Product Model is the scope source of truth. The Tech Spec is the tooling source of truth.

## Repo-Local Skills

- `.codex/skills/casprflow-mvp-build/SKILL.md` — end-to-end build sequence + scope guardrails.
- `.codex/skills/casprflow-macos-automation/SKILL.md` — hotkey, AX, paste, focus, capsule.
- `.codex/skills/casprflow-product-docs/SKILL.md` — product/planning docs, scope alignment.

If the runtime does not auto-discover repo-local skills, read the `SKILL.md` files manually before working.

## MVP Guardrails

- native macOS, menu-bar/background.
- fixed `Option + Space` hotkey, no picker.
- single `ScreenContextBundle` per capture.
- two-stage reply: 3 intent chips, then one expansion of the picked chip.
- Gemini for generation, not OpenAI.
- `Enter` pastes; no auto-send.
- local JSON learning, one visible learned label.
- no browser extension, mobile, accounts, sync, dashboards, embeddings, fine-tuning, analytics, or send detection unless scope is explicitly expanded.

## Source Reuse

- `bwarzecha/Axii` (Apache-2.0): menu-bar shell, hotkey, permission patterns, paste mechanics.
- `bytefer/macos-vision-ocr` (MIT): Vision OCR request/output shape.
- Preserve license headers; add `THIRD_PARTY_NOTICES.md` before public distribution.

## Working Rules

- Swift, SwiftUI, AppKit.
- keep UI minimal and keyboard-first.
- no large editor overlay.
- never auto-send.
- align docs whenever scope changes.
- run the narrowest useful validation before finishing a phase.
- one phase per PR: complete it, write the report under `docs/phase-reports/`, stop.

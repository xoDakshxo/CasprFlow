# CasprFlow Agent Instructions

## Project State

CasprFlow is currently a planning-first repo for a native macOS MVP.

Start by reading:

1. `docs/CasprFlow-Concept-v1.md`
2. `docs/CasprFlow-MVP-Initiation-v1.md`
3. `docs/CasprFlow-Tech-Spec-v1.md`
4. `docs/CasprFlow-Implementation-Plan-v1.md`

The implementation plan is the build-order source of truth. The tech spec is the tooling source of truth.

## Repo-Local Skills

Use these repo-local skills when relevant:

- `.codex/skills/casprflow-mvp-build/SKILL.md`
  - End-to-end MVP implementation sequence and scope guardrails.
- `.codex/skills/casprflow-macos-automation/SKILL.md`
  - Native macOS hotkey, selection capture, paste, focus, permission, and reply capsule work.
- `.codex/skills/casprflow-product-docs/SKILL.md`
  - Product docs, planning docs, and scope alignment.

If the runtime does not auto-discover repo-local skills, read the relevant `SKILL.md` manually before working.

## MVP Guardrails

Keep the MVP narrow:

- native macOS app
- menu-bar/background app
- fixed `Option + Space` hotkey
- no hotkey picker
- selection-first context capture
- tiny reply capsule
- one generated reply
- editable draft inside the capsule
- `Command + R` regenerate-from-edit
- `Enter` paste
- no auto-send
- local JSON learning
- one visible learned label

Do not add browser extensions, mobile, accounts, sync, app integrations, dashboards, embeddings, fine-tuning, analytics, or send detection unless the user explicitly expands scope.

## Source Reuse

Only use bulk source reuse when it saves meaningful time.

Approved current candidates:

- `bwarzecha/Axii`: Apache-2.0 primary port target for menu-bar app shell, global hotkey, permissions, focus restoration, and paste mechanics.
- `jxucoder/hold-to-talk`: Apache-2.0 fallback/reference for floating indicator and paste-anywhere behavior.

Preserve license headers and add attribution before public distribution if porting source.

## Working Rules

- Prefer Swift, SwiftUI, and AppKit.
- Keep UI minimal and keyboard-first.
- Do not build a large edit overlay.
- Do not auto-send messages.
- Use local files for MVP learning.
- Keep docs aligned when scope changes.
- Run the narrowest useful validation before finishing.


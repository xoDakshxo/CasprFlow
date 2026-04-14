---
name: casprflow-mvp-build
description: Build or modify the CasprFlow day-one MVP. Use when implementing the native macOS reply flow, sequencing work from the implementation plan, deciding MVP scope tradeoffs, or turning the docs into code for the menu-bar app, fixed hotkey, reply capsule, generation, paste, regeneration, and local learning loop.
---

# CasprFlow MVP Build

## Start Here

Read these repo docs before making product or architecture choices:

1. `docs/CasprFlow-Concept-v1.md`
2. `docs/CasprFlow-MVP-Initiation-v1.md`
3. `docs/CasprFlow-Tech-Spec-v1.md`
4. `docs/CasprFlow-Implementation-Plan-v1.md`

Treat the implementation plan as the source of truth for MVP sequence. If the docs disagree, prefer the implementation plan for build order and the tech spec for tooling choices.

## MVP Definition

The MVP is done when this loop works:

1. User highlights a message in another app.
2. User presses `Option + Space`.
3. CasprFlow captures selected text.
4. A tiny reply capsule appears.
5. One reply is generated.
6. User edits the reply directly in the capsule.
7. User can press `Command + R` to regenerate from the edited draft.
8. User presses `Enter`.
9. Final reply pastes into the active app.
10. CasprFlow stores a local learning signal.
11. The next reply shows one learned label.

## Build Rules

- Prefer native macOS: Swift, SwiftUI, AppKit.
- Keep the app menu-bar/background-first.
- Use fixed `Option + Space` hotkey in MVP.
- Do not add a hotkey picker unless the user explicitly re-scopes the MVP.
- Use a tiny reply capsule, not a bulky editor overlay.
- Preserve user control: paste, never send.
- Use local JSON for learning.
- Use one model call per generation or regeneration.
- Keep onboarding to permission guidance only.
- Avoid adding settings screens, dashboards, accounts, sync, analytics, or app integrations.

## Sequential Workflow

Implement in this order unless an existing codebase forces a small local adjustment:

1. App shell and menu-bar lifecycle.
2. Configurable global hotkey.
3. Selected-text capture.
4. Reply capsule.
5. Generation.
6. Regenerate-from-edit.
7. Paste into prior active app.
8. Local learning and learned label.
9. Demo pass in a small set of text surfaces.

Do not broaden scope until the above loop works twice in a row.

## Source Reuse

Use bulk reuse only where it saves meaningful native macOS time.

Primary port target:

- `bwarzecha/Axii`
- License: Apache-2.0
- Use for menu-bar shell, hotkey flow, permission pattern, focus restoration, and smart paste behavior.

Fallback/reference:

- `jxucoder/hold-to-talk`
- License: Apache-2.0 per public site
- Use only as a reference for floating indicator and paste-anywhere behavior if Axii blocks progress.

Do not port small repos for tiny helpers. Build trivial glue locally.

## Validation

For docs-only changes:

- run `rg -n "(TODO|TBD)" docs .codex/skills AGENTS.md` only if checking for unfinished markers
- inspect `git status --short`

For code changes once the app exists:

- run the repo's build command if present
- run focused tests if present
- manually validate hotkey, capture, capsule, regenerate, paste, and learning in at least Notes plus one browser text field

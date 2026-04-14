---
name: casprflow-product-docs
description: Update CasprFlow planning, product, MVP, technical, or implementation docs. Use when writing or revising docs under docs/, keeping scope aligned across the concept, MVP initiation, tech spec, and implementation plan, or making product tradeoff decisions about the one-day macOS MVP.
---

# CasprFlow Product Docs

## Source Order

Use the docs in this order:

1. `docs/CasprFlow-Concept-v1.md` for vision and product principles.
2. `docs/CasprFlow-MVP-Initiation-v1.md` for MVP boundaries.
3. `docs/CasprFlow-Tech-Spec-v1.md` for chosen technologies.
4. `docs/CasprFlow-Implementation-Plan-v1.md` for sequence and shortcuts.

When updating docs, keep all four aligned. If changing MVP scope, update every doc that would otherwise contradict the new direction.

## Product Invariants

Keep these intact:

- stay in the user's current communication flow
- selection-first context capture
- one generated reply
- tiny reply capsule, not a bulky overlay
- editable draft before paste
- fixed `Option + Space` hotkey
- `Command + R` regenerate-from-edit
- paste, never auto-send
- local learning from corrections
- visible learned label
- one-day MVP bias

## Writing Style

- Be direct and implementation-oriented.
- Separate MVP from future roadmap.
- Name deliberate shortcuts explicitly.
- Avoid vague claims like "AI learns your style" without explaining the local heuristic.
- Prefer checklists and done criteria over abstract product language.
- Keep docs ASCII unless updating text that already uses non-ASCII.

## Scope Discipline

Do not silently add:

- browser extension
- mobile app
- account system
- sync
- relationship memory
- deep app integrations
- model fine-tuning
- send detection
- large settings UI
- analytics dashboards

If a requested doc change introduces one of these, label it as post-MVP unless the user explicitly says to expand MVP scope.

## Source Reuse Documentation

Only document open-source reuse when it saves a large block of implementation time.

Approved current entries:

- `bwarzecha/Axii`: primary Apache-2.0 bulk port target for macOS app shell, hotkey, permissions, focus, and paste mechanics.
- `jxucoder/hold-to-talk`: Apache-2.0 fallback/reference for floating indicator and paste-anywhere UX.

Do not list tiny libraries for small features unless the user asks for a dependency audit.

## Doc Change Checklist

Before finishing a docs task:

1. Check for contradictory hotkey, overlay, learning, or timing claims.
2. Keep the MVP around 2-3 hours only if source reuse remains part of the plan.
3. Confirm hotkey picker is not included in MVP.
4. Confirm reply capsule and regenerate-from-edit are included.
5. Run `git status --short`.

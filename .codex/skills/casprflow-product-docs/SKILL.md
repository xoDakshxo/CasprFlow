---
name: casprflow-product-docs
description: Update CasprFlow product/architecture/implementation docs. Use when writing or revising docs under docs/, keeping scope aligned across README, architecture, decisions, latency, connectors, and the implementation phases, or making product tradeoff decisions about the voice agent dispatcher.
---

# CasprFlow Product Docs

## Source order

1. `docs/README.md` — vision + the three reference flows.
2. `docs/architecture.md` — universal primitives, intent shape, data flow.
3. `docs/decisions.md` — locked technical choices.
4. `docs/latency.md` — the latency contract.
5. `docs/connectors.md` — the kept native core.
6. `docs/implementation/` — phase gates (execution source of truth).

Keep all docs aligned. If you change direction, update every doc that would otherwise
contradict it — and `AGENTS.md`.

## Product invariants (keep intact)

- Voice-first: **no text box**. Hold **Option + Space** (push-to-talk) → speak → release.
- Wispr-style sine-wave HUD center-bottom that morphs into the CasprFlow spinner.
- Two-tier intent router: deterministic zero-network fast-path + OpenAI-nano fallback.
- Programmatic dispatch only (URL schemes, AppleScript, deep links, CLI) — never vision.
- **Universal dispatcher**: app-agnostic executor primitives + thin handlers. The three
  flows are examples, not the scope.
- **Latency is the product** — sub-second common path.
- Paste, **never auto-send**.
- Reuse the kept connector core; don't rewrite it.

## Writing style

- Direct, implementation-oriented. Checklists and done-criteria over abstract language.
- Name deliberate shortcuts and deferrals explicitly.
- Don't reintroduce the retired reply-capsule/chips product or its terms.

## Scope discipline

Label as future (not silently added): accounts, sync, mobile, browser extension, settings
UI beyond permissions, analytics dashboards, model fine-tuning. The SQL/ClickHouse artifact
flow is in-design (phase 6), not a silent add.

## Doc change checklist

1. Hotkey reads **Option + Space**, push-to-talk (press+release).
2. Input is voice-only — no text field anywhere.
3. Router fast-path is deterministic; LLM is fallback (OpenAI nano).
4. Executors are universal; handlers are thin; nothing app-specific leaks into the core.
5. "Never auto-send" preserved.
6. `git status --short`.

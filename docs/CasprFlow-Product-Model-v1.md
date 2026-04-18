# CasprFlow Product Model

This document is the canonical product spec for the post–Phase 3 direction. Read it together with `CasprFlow-Concept-v1.md` (the original wedge) and `CasprFlow-Tech-Spec-v1.md` (the technical surface).

## Core Loop

```text
context  ->  3 intent chips  ->  pick one  ->  full expansion  ->  paste
```

CasprFlow already understands the screen by the time the user presses `Option + Space`. It does not show three full drafts. It shows three short moves the user can pick in under a second, then expands the picked move into a full reply tailored to the current app.

## Why Chips, Not Drafts

Three full replies forces the user to read three paragraphs and choose. Chips reverse the load:

- the user picks an intent (a move) instantly
- CasprFlow does the writing once the move is locked
- the result already matches the surface tone (Slack vs Codex vs iMessage vs Mail)

This makes the product feel like an extension of intent, not a writing chooser.

## Surface Realization

The same bundle produces different chip sets per surface:

| Surface | Example chips | Expansion tone |
|---|---|---|
| Slack | Take it • Push timing • Ask context | coordination, brief |
| Codex (agent prompt) | Implement • Inspect first • Plan steps | imperative, agent-ready |
| iMessage / Messages | Yes • Soft no • Not sure | casual, short |
| Email | Confirm • Defer • Decline | structured, polite |
| Browser chat | Confirm • Clarify • Push back | match the chat tone |
| Code editor | Patch safely • Refactor • Add tests | technical, precise |
| Unknown | Confirm • Clarify • Decline | safe defaults |

Detection is rule-based on bundle id and field role first. Learned overrides come later.

## End-to-End Flow Example

Slack message: `"Can you add LinkedList access handling to the onboarding flow today?"`

1. User presses `Option + Space` in the Slack reply field.
2. CasprFlow assembles a `ScreenContextBundle`. `surface.kind = chat`.
3. Chip prompt returns `[Take it, Push timing, Ask context]`.
4. User picks `Take it` (key `1`).
5. Expansion prompt produces:
   > Yep, I can take this today. I'll handle the LinkedList access flow and post an update once I have a working pass.
6. User hits `Enter`. Paste happens, capsule closes.

Same scenario in Codex prompt box, picking `Implement`, would expand into an agent-ready instruction instead of a chat reply.

## Cross-App Momentum (later phase)

The selected move can carry across adjacent contexts within a short window. If the user picks `Patch then refactor` in Slack, the next Codex invocation can prefer chips like `Quick patch`, `Patch safely`, `Patch + leave notes`. Out of MVP scope but the bundle supports it.

## What CasprFlow Is Not

- not a writing surface
- not an autonomous agent
- not a chooser of three drafts
- not an app-specific integration (no Slack API, no Codex API)
- not a settings product

## Day-One Definition Of Done

The MVP is done when:

1. `Option + Space` in Slack, Notes, iMessage, or a code prompt box assembles a bundle within ~300 ms.
2. The capsule shows three surface-aware chips within ~800 ms.
3. Picking a chip produces one expansion within ~1.2 s when Gemini is fast.
4. `Enter` pastes the final text into the original field.
5. The user's edit before paste is stored and influences future expansions.
6. A small learned label appears once at least one signal is collected.

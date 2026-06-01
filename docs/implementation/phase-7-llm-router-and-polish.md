# Phase 7 — LLM router fallback + latency polish

## Goal

Handle the long tail: commands the deterministic router doesn't match get classified by
a fast LLM into the same `Intent` shape. Then tighten the latency tactics across the
whole pipeline.

## Build — Tier-1 LLM router

- `Sources/CasprFlowCore/Routing/LLMRouter.swift` — wraps `LLMClient` with a strict JSON
  schema that returns `{ kind, slots, confidence }`. Called by `IntentRouter` **only when
  Tier-0 returns `.unknown`**.

```swift
// textFormat = json_schema with: kind (enum of IntentKind), slots (object), confidence (number)
let json = try await llm.complete(
    prompt: classificationPrompt(text),
    instructions: routerInstructions,   // "Classify the command into one intent. Output only JSON.",
    textFormat: intentSchema,
    maxOutputTokens: 120
)
```

- Keep the prompt tiny and the schema strict. `reasoning.effort = low`. Parse → `Intent`;
  on parse failure or low confidence, fall back to `.unknown` (HUD: "didn't catch that").
- The enum of valid kinds in the schema must stay in sync with `IntentKind`.

Implementation note: this router has been pulled forward before phases 5/6. Tier-0 still
owns the known fast command shapes and never touches the network. Tier-1 only classifies
`.unknown` transcripts into the same `Intent` enum and slot dictionary. The built strict
schema uses explicit nullable slot keys rather than an open dynamic slot object because
OpenAI strict structured outputs reject dynamic additional properties in this shape.

## Build — latency polish

Implement the tactics in [`../latency.md`](../latency.md) that aren't in yet:

- `LLMClient.preconnect()` at app launch (warm TLS to the OpenAI endpoint).
- One long-lived `URLSession` shared by the client.
- Speculative prefetch on high-confidence Tier-0 prefixes (begin app launch while
  finalizing slots).
- Latency logging: timestamp `submit`, `route-done`, `dispatch-done`; print deltas in
  debug builds.
- Verify the panel is never reallocated on the hotkey path; the optimistic spinner shows
  before routing.

## Build — learned project names

Project/file path resolution must not rely on one repo-specific hardcoded speech alias.
The swarm path uses:

- `ProjectAliasStore` under `~/Library/Application Support/CasprFlow/project-aliases.json`.
- `ProjectResolver` exact lookup plus fuzzy folder search under known code roots.
- `ProjectClarificationService` only when the resolver finds likely candidates but cannot
  safely choose. The chosen path is saved against the spoken phrase for future runs.

## Acceptance

- A non-templated command ("pull up the quarterly revenue dashboard") routes via Tier-1
  to a sensible `Intent` + handler.
- Tier-0 commands never touch the network (verify via logging).
- Latency log shows Tier-0 `submit → dispatch-done` < 150 ms; Tier-1 adds only the model
  round-trip (~300–600 ms warm).
- `swift build` green, `CasprFlowChecks` passes (schema/parse round-trip asserts).

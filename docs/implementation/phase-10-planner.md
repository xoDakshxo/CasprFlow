# Phase 10 — Planner (LLM → multi-step Plan)

## Goal

The long-tail brain. On a FastRouter miss, the planner interprets an arbitrary spoken
task and emits an **ordered, multi-step `Plan` of `CapabilityCall`s**, choosing the
cheapest tier that works (D2, D10). One round-trip, strict structured JSON, then local
execution. No live network in tests — everything stub-driven.

## Build

`Sources/CasprFlowCore/Routing/Planner.swift`:

```swift
public struct Planner: Sendable {
    public init(client: LLMCompleting = LLMClient(),
                catalog: @escaping @Sendable () -> [CapabilityDescriptor])
    /// Miss-path only. Returns a validated multi-step plan, or an empty plan → "unknown".
    public func plan(_ text: String, context: PlannerContext) async -> Plan
}

public struct PlannerContext: Sendable {
    public let frontmostAppBundleID: String?
    public let now: Date
    // kept tiny on purpose — context bloat costs tokens and latency
}
```

### The planner prompt (instructions + catalog)

- **Instructions** (system): "You convert one spoken macOS command into an ordered plan
  of capability calls. Prefer the cheapest tier: use direct programmatic capabilities
  first; use `run_task` only for multi-step tasks whose next action depends on a result;
  use `control_ui` only when no programmatic capability fits the target app. Never invent
  capabilities or arguments. Outward/irreversible actions must use the capability marked
  for confirmation — never auto-send. Return only JSON matching the schema."
- **Catalog**: serialize `CapabilityRegistry.catalog()` into the prompt — each entry's
  `name`, `summary`, `sideEffect`, and argument schema. This is what makes the planner
  open-ended: add a capability → it appears in the catalog → the planner can use it, no
  prompt rewrite.
- Pass `frontmostAppBundleID` + `now` so the planner can target the focused app.

### Strict output schema

Reuse the `LLMClient.complete(textFormat:)` strict-JSON path. Schema:

```jsonc
{
  "type": "json_schema", "name": "casprflow_plan", "strict": true,
  "schema": {
    "type": "object", "additionalProperties": false,
    "required": ["steps", "rationale"],
    "properties": {
      "rationale": { "type": "string" },          // one short line, for logs/HUD
      "steps": {
        "type": "array",
        "items": {
          "type": "object", "additionalProperties": false,
          "required": ["capability", "arguments"],
          "properties": {
            "capability": { "type": "string" },     // validated against the registry
            "arguments": { "type": "string" }        // JSON-encoded object string*
          }
        }
      }
    }
  }
}
```

\*Arguments-as-encoded-string keeps the schema strict and closed regardless of which
capabilities exist; the planner emits `arguments` as a JSON object string, the parser
decodes it into `[String: JSONValue]`. (Alternative: a fixed superset of slot keys like
v2's `slotKeys`. Prefer the encoded-string approach so the schema doesn't have to grow
per capability — but document whichever is chosen.)

### Parse + validate (defensive)

`Planner` owns a static `parsePlan(_ json:, registry:) -> Plan`:

- Drop steps whose `capability` is not registered.
- Decode each step's `arguments` into `[String: JSONValue]`; drop steps that fail to
  decode.
- Drop steps missing a required arg (per the capability schema) unless the capability
  declares that arg resolvable via clarify (phase 11 handles the gate; phase 10 just
  keeps the step if the capability can clarify).
- Clamp plan length (e.g. ≤ 8 steps).
- Empty result → `Plan(steps: [], source: .planner)` = "couldn't interpret".

Make `parsePlan` **pure and stub-tested** — this is the unit under test.

## Reuse

- `LLMClient` / `LLMCompleting` (inject a stub in checks), the strict-JSON `textFormat`
  plumbing, `SelectionTextNormalizer`. The config (`gpt-5.4-nano`, low reasoning, small
  `max_output_tokens`) is already wired.

## Latency budget

- Planner is **miss-path only** and its round-trip is hidden by speculative planning
  (phase 11) — but still: `reasoning.effort = low`, `max_output_tokens` small (≈ 200),
  one request. No multi-call planning.
- `parsePlan` is pure/synchronous and must be `< 1 ms`.

## Acceptance

- `swift build` green; `CasprFlowChecks` passes — **no live network**.
- New `CasprFlowChecks` assertions (stub `LLMCompleting` returning canned JSON):
  - A single-step plan JSON parses to one valid `CapabilityCall` with decoded args.
  - A multi-step plan JSON parses to ordered steps in order.
  - A step naming an unregistered capability is dropped.
  - A step with malformed `arguments` is dropped; valid siblings survive.
  - Plan length clamps at the max.
  - The generated plan schema is `strict: true` with closed objects and correct
    `required` arrays (mirror the v2 schema-shape assertions).
  - Catalog serialization includes a capability's name, summary, and required args.
- Manual: not wired into the app yet (phase 11). Verified by checks here.

## Out of scope

- Executing plans, speculative planning, clarify/confirm, `AppCoordinator` wiring — all
  phase 11. The `TaskAgent` loop is phase 12; the planner only *emits* a `run_task` step,
  it doesn't run one.

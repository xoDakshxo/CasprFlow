# Phase 9 — Wide FastRouter (the latency moat)

## Goal

Build the deterministic, **zero-network** router that turns the *majority* of everyday
spoken commands into a single `CapabilityCall` in **< 2 ms**. This is the moat that keeps
the planner (network) off the common path (D0, D3). The v2 `DeterministicRouter` had 8
regexes; v3's FastRouter must be deliberately **wide** — synonym-tolerant, slot-tolerant —
because every command it misses pays a model round-trip.

## Build

`Sources/CasprFlowCore/Routing/FastRouter.swift`:

```swift
public struct Plan: Equatable, Sendable {
    public let steps: [CapabilityCall]
    public let rationale: String?      // nil for fast-path; set by planner
    public let source: PlanSource      // .fastRouter | .planner
}
public enum PlanSource: String, Sendable { case fastRouter, planner }

public struct FastRouter: Sendable {
    public init(capabilities: [any Capability])
    /// Zero-network. Returns a one-step plan, or nil → caller falls to the planner.
    public func route(_ text: String) -> Plan?
}
```

`FastRouter.route` normalizes the text once, then asks each capability's `fastMatch` (in
priority order) and/or applies a shared **command-family grammar**. First claim wins.

### Implement `fastMatch` on the builtin capabilities (phase 8 left these nil)

Cover these families with generous synonyms. Each row = the phrasings that must match at
zero network and the resulting call:

| Family | Trigger phrasings (synonym-tolerant) | Call |
|---|---|---|
| open app | "open / launch / start / fire up / bring up \<app>" (where target isn't a URL) | `open_app{app}` |
| open url | "open / go to / navigate to \<domain-or-url>", bare `foo.com`, `https://…` | `open_url{url}` |
| web search | "search / google / look up / find / get me \<q> [from google]" | `web_search{query, engine?}` |
| run shell | "run / execute \<cmd>" (allowlisted only; else `.confirm`) | `run_shell{command}` |
| spawn swarm | "spin up / start / launch \<n> agents [on \<proj>] [for/to \<task>]" | `spawn_swarm{count, project?, task?, tool?}` |
| paste / reply | "reply / respond / tell / message \<who> [that/saying] \<msg>" | `paste_text{recipient?, message}` (`.confirm`) |

Keep the existing regex assets from `DeterministicRouter` and `SwarmSpecBuilder` (spoken
number map, URL normalization, task splitting) — **move/reuse, don't rewrite**. Widen the
trigger verb sets. The goal is high recall on the common families with precise slotting.

### Disambiguation rules (deterministic, documented)

- "open \<x>": if `<x>` normalizes to a URL/domain → `open_url`, else `open_app`. (kept)
- Priority order so a more specific family wins (swarm before generic "start", search
  "find" before app "find"). Document the order in the file header.
- If a phrase is plausibly two families with no deterministic winner, return **nil**
  (let the planner decide) rather than guess — a wrong fast match is worse than a planner
  hop.

### Confidence / miss signal

`route` returns `Plan?`. `nil` means "not confidently mine" → planner. There is no
fuzzy/low-confidence fast match; fast-path is all-or-nothing at confidence 1.

## Reuse

- `SelectionTextNormalizer`, the `DeterministicRouter.normalize` helper, the spoken-number
  map, `BrowserSearchURLBuilder`, URL normalization, `SwarmTaskSplitter`. Lift the regex
  bodies out of `DeterministicRouter` into the capabilities' `fastMatch`.
- After this phase, `DeterministicRouter` is dead code — delete it and its
  `CasprFlowChecks` block once the FastRouter checks replace them (do it in this PR to
  avoid two routers lingering).

## Latency budget

- `route` (hit or miss decision): **< 2 ms**, no allocation churn, no network, no I/O.
- Normalize the input string **once**; don't re-lowercase per rule.
- Add a `CasprFlowChecks` timing-style assertion is optional, but the family-coverage
  assertions below are required.

## Acceptance

- `swift build` green; `CasprFlowChecks` passes.
- New `CasprFlowChecks` assertions (port + widen the old router tests):
  - Each command family matches **multiple** phrasings to the right `CapabilityCall` with
    correct slots — e.g. all of "open figma", "launch figma", "fire up figma" →
    `open_app{app: figma}`.
  - "go to example.com" and "example.com" → `open_url{url: https://example.com}`.
  - "spin up 3 agents on casprflow for ui docs, tests, and cleanup" →
    `spawn_swarm{count: 3, project: casprflow, task: …}` (reuse phase-4 slot assertions).
  - A genuinely long-tail phrase ("get this doc ready for prachi") → `route` returns
    `nil` (planner territory) — **not** a wrong guess.
  - Ambiguous-but-no-winner phrase → `nil`.
- Manual: the previously-working spoken commands still dispatch (once wired in phase 11);
  for this phase, verify via checks since the live app still uses the legacy path until
  phase 11.

## Out of scope

- The planner, speculative planning, multi-step plans, orchestrator wiring. FastRouter
  only ever returns a **one-step** plan or nil.

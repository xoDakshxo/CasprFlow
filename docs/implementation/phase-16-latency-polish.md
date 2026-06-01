# Phase 16 — Latency hardening, telemetry, polish

## Goal

Make the latency contract **measured and held**, not assumed. Add tier/speculation
telemetry, graceful degradation, preconnects, config surface, and capability allowlists.
Nothing here adds user ability — it protects D0 across everything 8–15 built.

## Build

### Telemetry (`Sources/CasprFlowCore/Routing/DispatchTelemetry.swift`)

- Per dispatch, record: `tier` (fastRouter | planner | agent), `speculationHit` (bool),
  and timings `release → route-done → plan-done → dispatch-done`.
- Maintain a rolling **FastRouter hit-rate** and surface it in debug logs and a menu-bar
  debug readout. A hit-rate drop is the early warning that latency is regressing.
- Pure aggregation logic (rolling counters, percentiles) is unit-tested.

### Graceful degradation

- **Planner timeout** (e.g. 1.5 s): if the planner doesn't return, fall back to a single
  clarify prompt ("Say that again as a direct command?") rather than hanging. The HUD
  never spins indefinitely.
- **Speculation correctness:** confirm a stale speculation is cancelled and never executed;
  re-plan on material partial change. Add an assertion that speculation never triggers a
  side-effect (plan-only).
- **Vision unconfigured / permission missing:** `control_ui` reports the exact missing
  permission and routes to the existing guide — never a silent no-op.

### Preconnects + warm paths

- `LLMClient.preconnect()` at launch (kept). Add vision-endpoint preconnect when
  `computer_use_enabled` (phase 14).
- Verify single long-lived `URLSession` reuse for both clients.
- Confirm the HUD panel (and `ArtifactWindow` if hot) are allocated once.

### Config surface (`casprflow.config.local.json`)

Document and load: `openai_api_key`, `openai_model`, `openai_reasoning_effort`,
`anthropic_api_key`, `computer_use_model`, `computer_use_enabled`, `planner_timeout_ms`,
`fast_router_min_hit_rate` (warn threshold), plus the existing `user_name`/`user_style`.

### Capability allowlist / safety

- A config allowlist of enabled capabilities (so a deployment can disable `control_ui` or
  `run_shell` entirely). The registry honors it.
- Re-audit `run_shell`: anything outside `ShellCommandPolicy`'s allowlist is `.confirm`,
  not blocked — let the user approve, but never auto-run destructive shell.

## Reuse

- The phase-11 latency logging scaffold (extend, don't replace), `LLMConfig`, the
  permission stack.

## Latency budget

- This phase **is** the budget enforcement. Acceptance = the measured numbers below.

## Acceptance

- `swift build` green; `CasprFlowChecks` passes.
- New `CasprFlowChecks` assertions:
  - Telemetry rolling hit-rate + timing aggregation compute correctly over a sequence.
  - Planner-timeout path returns the clarify fallback (stub a slow/never planner).
  - Speculation-cancel path never dispatches (plan-only invariant).
  - Allowlist disables a capability: the registry omits it from catalog + refuses dispatch.
- Manual / measured:
  - Tier-1 (FastRouter) `release → dispatch-done` **< 150 ms** on the demo commands
    (excl. app launch), logged.
  - A speculative planner hit feels sub-second end-to-end.
  - FastRouter hit-rate on a sample command set is reported and above the configured
    threshold.
  - `control_ui` AX action **< 150 ms**; vision clearly shows "working" and is only
    reached after an AX miss.

## Out of scope

- New capabilities or model providers. This phase only measures, hardens, and degrades
  gracefully.

# Phase 12 — TaskAgent (in-app agent loop)

## Goal

The tier-2 brain: an **in-app** observe→think→act loop that accomplishes a multi-step
desktop task on the user's behalf, calling capabilities (programmatic + later
`control_ui`) until the goal is met. Exposed as the `run_task` capability the planner can
emit. This is distinct from `spawn_swarm` (out-of-process terminal coding agents) — see
D12. Used **only** when the next action depends on a runtime observation (D10); a knowable
multi-step task should be a flat plan, not an agent.

## Build

`Sources/CasprFlowCore/Agent/TaskAgent.swift`:

```swift
@MainActor
public final class TaskAgent {
    public init(client: LLMCompleting,
                registry: CapabilityRegistry,
                maxSteps: Int = 8)
    /// Run until the model emits `finish`, the step budget is hit, or a step errors.
    public func run(goal: String, context: ExecutionContext) async -> CapabilityResult
}
```

`Sources/CasprFlowCore/Capabilities/Builtin/RunTaskCapability.swift`:

```swift
public struct RunTaskCapability: Capability {
    public let name = "run_task"
    public let summary = "Perform a multi-step task on the user's machine when the next \
step depends on the result of the previous one. Prefer single capabilities when the \
steps are known in advance."
    public let sideEffect: SideEffect = .local   // inner steps carry their own; confirm still gates
    public var parameters: CapabilitySchema { .init(parameters: [
        .init(name: "goal", type: "string", description: "The full task to accomplish", required: true)
    ]) }
    // execute → builds a TaskAgent, runs it, returns the loop result.
}
```

### Loop algorithm

1. Build an **agent capability subset** from the registry — exclude `run_task` itself
   (recursion guard, D12) and `spawn_swarm` (different concept). Include `control_ui` once
   it exists (phases 13–14).
2. Each iteration, call the model with: the **goal**, the **capability subset catalog**,
   and the **observation history** (compact: each prior call + its `observation`/`message`).
   Strict JSON output is one of:
   - `{ "action": "call", "capability": "...", "arguments": "{...}" }`
   - `{ "action": "finish", "summary": "..." }`
3. On `call`: validate against the registry, run the **confirm gate** for `.confirm`
   capabilities (the agent never bypasses D8), dispatch, append the `CapabilityResult`'s
   `observation` (or `message`) to history.
4. On `finish`, or at `maxSteps`, or on a hard step error → return a `CapabilityResult`
   summarizing what happened.
5. Keep history compact (cap tokens): summarize/trim old observations so each hop stays
   small and fast.

### Safety / guardrails

- **Recursion guard:** a `TaskAgent` cannot call `run_task`. Enforce in the subset, not
  just the prompt.
- **Confirm still gates** every `.confirm` capability inside the loop — the agent cannot
  send/destroy without the user. Never auto-send (D8).
- **Step budget** (`maxSteps`, default 8) and a wall-clock ceiling so a confused agent
  can't loop forever; on budget exhaustion, report partial progress honestly.
- **Cancellable:** Escape in the HUD cancels the running task (cooperative cancellation).

## Reuse

- `LLMClient`/`LLMCompleting`, `CapabilityRegistry`, `ExecutionContext`, the confirm/clarify
  hooks from phase 11, `VoiceHUDController` for progress + cancel.

## Latency budget

- Each hop: `< 600 ms` (nano, tiny output). Minimize hops — the prompt must push the
  model to `finish` as soon as the goal is met, and to prefer the fewest calls.
- The loop is tier 2 (seconds), acknowledged. It must only be entered when the planner
  genuinely needs it — the HUD shows a working/progress state throughout.

## Acceptance

- `swift build` green; `CasprFlowChecks` passes — **no network**.
- New `CasprFlowChecks` assertions (stub `LLMCompleting` scripted to emit a sequence of
  `call`s then `finish`; stub capabilities):
  - The loop executes the scripted calls **in order**, feeding each observation back.
  - `finish` ends the loop and returns the summary.
  - `maxSteps` caps a non-finishing loop and reports partial progress.
  - A `.confirm` capability inside the loop respects a `confirm → false` (not executed).
  - The agent subset **excludes** `run_task` (recursion guard) and `spawn_swarm`.
  - A failing dispatched step ends the loop with an honest failure summary.
- Manual smoke: a spoken multi-step task that the planner routes to `run_task` (e.g.
  "find the latest invoice in Mail and copy the total") runs several capability calls and
  reports a result — using only programmatic capabilities until `control_ui` lands.

## Out of scope

- `control_ui` itself (phases 13–14) — `run_task` will simply have it available in its
  subset once those ship. No parallel agents (that's `spawn_swarm`'s domain).

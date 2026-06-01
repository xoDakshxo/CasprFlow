# Codex implementation plan — CasprFlow v3 Agentic Orchestrator

This is the contract between you (Codex, implementing) and the reviewer (Claude, reviewing
your PRs on the user's behalf). Read [`../architecture.md`](../architecture.md),
[`../decisions.md`](../decisions.md), [`../latency.md`](../latency.md), and
[`README.md`](README.md) first. Then work the phases **8 → 16 in strict order**, one PR
each.

## The mission in three sentences

CasprFlow turns a held-Option+Space spoken command into action on the user's Mac, in
realtime. v3 replaces the brittle classify-into-fixed-enum router with a **wide
deterministic fast-path → (on miss) an LLM planner → ordered capability calls**, spanning
three tiers: programmatic, in-app agent loop, and computer-use. **Ultra-low latency is the
governing constraint** — the common path never touches the network, the planner is hidden
behind speculative planning, and computer-use is the rare last resort.

## What "done" means for each phase

A phase PR is complete only when **all** of these hold:

1. `swift build` passes.
2. `swift run CasprFlowChecks` passes, **with new assertions for every new pure-logic
   unit** added this phase.
3. The phase's **latency budget** (in its doc and [`../latency.md`](../latency.md)) is met
   and, where it touches the hot path, **logged/measured**.
4. The phase's **acceptance list** (in its doc) is satisfied, including the manual smoke.
5. No live network or real screen control in `CasprFlowChecks` — planner, agent, and
   vision are exercised through injected stubs (`LLMCompleting`, `ComputerUseModel`,
   service spies).
6. Scope is exactly the phase — no jumping ahead, no broadening.
7. Docs updated if a seam changed.

## How to work

- **Reuse the kept core; do not rewrite it.** Wire into `AppCoordinator`, `FloatingPanel`,
  `HotkeyService`, `PasteService`, `LLMClient`, the executors
  (`URLSchemeLauncher`/`AppLauncher`/`ShellRunner`/`AppleScriptRunner`/`SwarmHost`), and
  the permission stack. See [`../connectors.md`](../connectors.md). The phase-3/4 executors
  and the phase-4 swarm are **kept** — v3 wraps them as capabilities, it does not replace
  them.
- **Group new code by role** under `Sources/CasprFlowCore/`: `Input/`, `Routing/`,
  `Capabilities/` (+ `Capabilities/Builtin/`), `Exec/`, `Agent/`, `ControlUI/`.
- **Capability is the only extension point.** Adding ability = a new `Capability` +
  registry entry (+ optional `fastMatch`). Never a new enum case or bespoke plumbing.
- **Pure logic must be testable without the app.** Matchers, schema builders, plan
  parsers, AX selectors, coordinate math — all pure, all asserted in `CasprFlowChecks`.
- **Latency is acceptance, not aspiration.** If a feature can't hit its tier budget, change
  the approach. Widen FastRouter rather than letting commands fall to the planner. Prefer a
  single up-front plan over an iterating agent. AX before vision, always.
- **Never auto-send.** `.confirm` side-effects gate; outward actions paste-not-send.
- **Stubs in, secrets out.** No credentials in code; read config/env. Inject model clients
  so tests are offline.

## PR conventions (so review is fast)

- **One phase per PR.** Title: `[v3][Phase N] <short title>`.
- **PR body must include:**
  - the phase number + a one-paragraph summary of what landed,
  - the **new `CasprFlowChecks` assertions** added (list them),
  - the **latency note**: which tier(s) this touches and the measured/expected numbers,
  - anything intentionally deferred to a later phase,
  - confirmation that `swift build` + `CasprFlowChecks` are green.
- Keep diffs focused; delete superseded code **in the phase that replaces it** (e.g.
  phase 9 deletes `DeterministicRouter`; phase 11 deletes `IntentRouter`/`LLMRouter`/old
  handlers). Don't leave two brains in the tree.
- If a decision needs to change, say so in the PR and update
  [`../decisions.md`](../decisions.md) — don't silently diverge.

## Reviewer's checklist (what Claude checks on every PR)

This is exactly what the review will grade. Self-check against it before opening the PR.

**Correctness**
- [ ] Builds; `CasprFlowChecks` green; new pure logic has assertions.
- [ ] Capability schemas are strict/closed; `required` lists only required args.
- [ ] Plan/agent parsers drop unknown capabilities + malformed args defensively.
- [ ] Stop-on-failure, recursion guard, step/time budgets present where specified.

**Latency (D0 — the hard gate)**
- [ ] No new network hop on the tier-1 / FastRouter path.
- [ ] FastRouter stays `< 2 ms`, wide coverage; misses are genuine long-tail, not lazy
      gaps. Hit-rate not regressed.
- [ ] Planner is miss-path only and uses small output / low reasoning / one request.
- [ ] Speculation is plan-only, debounced, single-in-flight, cancellable, never side-effects.
- [ ] `control_ui` tries AX first; vision is gated + last; HUD shows "working" for vision.
- [ ] Hot-path windows are prewarmed, not per-invoke allocated.

**Safety**
- [ ] `.confirm` gates every outward/irreversible action; `paste_text` never sends.
- [ ] Destructive shell is confirm, not auto-run.
- [ ] Vision receives only screenshot + goal + history; no extra data leaves the machine.

**Hygiene**
- [ ] Reuses kept executors; no app-specific knowledge leaked into the core.
- [ ] Superseded code deleted; one brain in the tree.
- [ ] Docs updated for any changed seam.

## Phase dependency map

```
[1 Voice HUD ✓]
      │
[8 Capability model] → [9 FastRouter] → [10 Planner] → [11 Orchestrator+gates+speculation]
                                                              │
                          ┌───────────────────────────────────┤
                          ▼                                   ▼
                 [12 TaskAgent]                     [15 Artifact + paste]
                          │
              [13 control_ui: AX] → [14 control_ui: vision]
                          │
                    [16 Latency hardening + polish]
```

8–11 are the brain and must land first and clean. 12 adds the in-app agent loop. 13→14 add
the computer-use escape hatch (AX before vision). 15 is the artifact/draft flow. 16
measures and enforces the latency contract across all of it.

## Anti-goals (do not do these)

- Don't reintroduce a fixed `IntentKind` enum or per-action plumbing.
- Don't make the planner the default path or skip the FastRouter.
- Don't use vision where AX or a programmatic capability works.
- Don't auto-send or auto-run destructive actions.
- Don't put credentials in code or make `CasprFlowChecks` hit the network.
- Don't broaden a phase or merge two phases into one PR.

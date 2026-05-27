# Phase 4 — Agent swarm

## Goal

"Spin up 5 agents and refactor the UI docs" → a terminal opens with N panes, each
running a headless Claude Code or Codex CLI instance on the task. The terminal is an
implementation detail behind a `SwarmHost` protocol — Warp first, tmux/iTerm later.

## Build

- `Sources/CasprFlowCore/Exec/SwarmHost.swift` — the protocol + a `WarpHost` impl.
- `Sources/CasprFlowCore/Handlers/AgentSwarmHandler.swift` — `.agentSwarm` → build a
  `SwarmSpec` from slots → hand to the configured `SwarmHost`.

```swift
struct SwarmPane { let title: String; let command: String; let cwd: URL }
struct SwarmSpec { let panes: [SwarmPane] }

protocol SwarmHost {
    func launch(_ spec: SwarmSpec) async throws
}
```

## WarpHost

Warp reads YAML launch configurations from
`~/.warp/launch_configurations/<name>.yaml` and opens them via
`open "warp://launch/<name>"`. Write a config with one tab split into N panes, each pane
running the agent command, then open the URL.

Per-pane command shape (tool from the `tool` slot, default `claude`):
```
cd <cwd> && claude -p "<task> (agent <i> of <n>)"
# or: cd <cwd> && codex exec "<task> (agent <i> of <n>)"
```
`claude` lives at `~/.local/bin/claude`, `codex` at `/opt/homebrew/bin/codex`. Resolve
full paths (login shells may differ). Headless/non-interactive flags so each pane runs
the task and reports.

> **The agent panes need the full intent.** Each pane's prompt must carry the complete
> task plus enough framing that a fresh agent knows what to do without the user present:
> the goal, the working directory, which slice it owns (agent i of n), and to report
> when done. A vague prompt produces vague work — see
> [`../../AGENTS.md`](../../AGENTS.md) and craft the per-pane prompt deliberately.

## Swappable hosts (later)

- `TmuxHost` — `tmux new-session -d`, `split-window` ×(N-1), `send-keys` per pane, then
  `open -a <terminal>` attached. Bundleable + headless + deterministic. (`tmux` not yet
  installed.)
- `iTermHost` — AppleScript splits + typed commands.

The handler must not change when the host changes.

## Reuse

- `ShellRunner` / `URLSchemeLauncher` from phase 3.
- Spoken-number → digit normalization from the router (phase 2).

## Acceptance

- "spin up 3 agents to refactor the UI docs" → Warp opens with 3 panes, each running an
  agent on the task in the right directory.
- Swapping the configured `SwarmHost` to a stub is a one-line change in wiring.
- `swift build` green, `CasprFlowChecks` passes (SwarmSpec builder + per-pane command
  assertions).

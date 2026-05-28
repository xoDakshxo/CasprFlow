# Phase 4 — Agent swarm

## Goal

"Spin up 3 agents on casprflow for UI docs, tests, and cleanup" → Ghostty opens with N
native panes, each running interactive Codex on an expanded scoped task. The terminal is an
implementation detail behind a `SwarmHost` protocol — Ghostty is the default because it
provides native scriptable panes without a nested multiplexer.

## Build

- `Sources/CasprFlowCore/Exec/SwarmHost.swift` — the protocol + alternate
  `TmuxHost`/`WarpHost` impls.
- `Sources/CasprFlowCore/Exec/GhosttyHost.swift` — the default Ghostty AppleScript host.
- `Sources/CasprFlowCore/Exec/ProjectResolver.swift` — default repo + alias/exact-folder
  resolver for short project names such as `casprflow` and `this project folder`.
- `Sources/CasprFlowCore/Handlers/AgentSwarmHandler.swift` — `.agentSwarm` → build a
  `SwarmSpec` from slots → hand to the configured `SwarmHost`.

```swift
struct SwarmPane { let title: String; let command: String; let cwd: URL }
struct SwarmSpec { let panes: [SwarmPane] }

protocol SwarmHost {
    func launch(_ spec: SwarmSpec) async throws
}
```

## GhosttyHost

`GhosttyHost` uses Ghostty's AppleScript dictionary to create a native window, split
additional terminals, set each terminal's working directory, then sends each Codex
command into the corresponding pane:

```
new window with configuration <cwd>
split pane1 direction right/down with configuration <cwd>
input text <command> to paneN
send key "enter" to paneN
```

Per-pane command shape (tool from the `tool` slot, default `codex`):
```
cd <cwd> && codex
cd <cwd> && codex "<full expanded prompt>"
# or: cd <cwd> && claude -p "<full expanded prompt>"
```
`claude` lives at `~/.local/bin/claude`, `codex` at `/opt/homebrew/bin/codex`. Resolve
full paths (login shells may differ). Codex uses the interactive CLI entrypoint so each
pane matches the experience of typing `codex` directly, with the expanded prompt already
seeded.

> **The agent panes need the full intent.** Each pane's prompt must carry the complete
> task plus enough framing that a fresh agent knows what to do without the user present:
> the goal, the working directory, which slice it owns (agent i of n), and to report
> when done. A vague prompt produces vague work — see
> [`../../AGENTS.md`](../../AGENTS.md) and craft the per-pane prompt deliberately.

The user should not have to dictate that full prompt. The deterministic router accepts
short forms like `spin up 3 agents on casprflow for UI docs, tests, and cleanup`.
`ProjectResolver` resolves the project slot from the current repo alias first, then exact
folder matches under `~/Code` and `~/Code/ExternalProjects`. `SwarmTaskSplitter` maps a
comma/`and` task list onto panes. If no explicit task is present (`spin up 3 agents`),
each pane opens plain interactive Codex with no seeded prompt.

## Swappable hosts

- `TmuxHost` — `tmux new-session -d`, `split-window` x(N-1), `send-keys` per pane, then
  opens Terminal attached. Useful fallback, but not the default because the visible
  nested tmux UI is a poor swarm surface.
- `WarpHost` — writes launch-config YAML and opens `warp://launch/...`. Kept as an
  alternate, but not the default because the installed Warp build did not reliably
  resolve generated launch config files by URI.
- `iTermHost` — AppleScript splits + typed commands.

The handler must not change when the host changes.

## Reuse

- `ShellRunner` / `URLSchemeLauncher` from phase 3.
- Spoken-number → digit normalization from the router (phase 2).

## Acceptance

- "spin up 3 agents to refactor the UI docs" → Ghostty opens with 3 native panes, each
  running an agent on the task in the right directory.
- "spin up 3 agents" → Ghostty opens with 3 native panes, each running plain interactive
  Codex with no seeded prompt.
- "spin up 3 agents on casprflow for UI docs, tests, and cleanup" → Ghostty opens with
  3 panes in the CasprFlow repo, with owned tasks split across panes.
- Swapping the configured `SwarmHost` to a stub is a one-line change in wiring.
- `swift build` green, `CasprFlowChecks` passes (SwarmSpec builder + per-pane command
  assertions).

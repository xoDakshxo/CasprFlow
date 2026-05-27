# Phase 3 — Executor primitives + first end-to-end dispatch

## Goal

Build the **universal executor layer** and the first generic handlers on top of it.
This is the phase that proves sub-second end-to-end dispatch (browser-search demo).
These primitives are app-agnostic and back every future handler — invest here.

## Build — executors (`Sources/CasprFlowCore/Exec/`)

- `URLSchemeLauncher.swift` — open any URL / deep link via `NSWorkspace.shared.open`.
- `AppLauncher.swift` — launch/focus any app by bundle id or name
  (`NSWorkspace.openApplication` / `URL(fileURLWithPath:)`).
- `AppleScriptRunner.swift` — run arbitrary AppleScript/JXA (`NSAppleScript` or
  `osascript` via `Process`). Return stdout/result, surface errors.
- `ShellRunner.swift` — run any shell/CLI command via `Process`, capture stdout/stderr +
  exit code, with a timeout. Used by swarm/SQL/anything CLI.

```swift
enum Executor {
    static func openURL(_ url: URL)
}
struct ShellRunner {
    func run(_ cmd: String, args: [String], cwd: URL?, timeout: TimeInterval) async throws -> ShellResult
}
struct ShellResult { let exitCode: Int32; let stdout: String; let stderr: String }
```

Keep them small, dependency-free, and reusable. No app-specific logic here.

## Build — generic handlers (`Sources/CasprFlowCore/Handlers/`)

- `OpenURLHandler.swift` — `.openURL` → `URLSchemeLauncher`.
- `OpenAppHandler.swift` — `.openApp` → `AppLauncher` (resolve common app names → bundle ids).
- `BrowserSearchHandler.swift` — `.browserSearch` → build a search URL
  (`https://www.google.com/search?q=<percent-encoded query>`) → `URLSchemeLauncher`.
  Default browser handles it; no app hardcoding.
- `ShellCommandHandler.swift` — `.shell` → `ShellRunner` (guarded; see safety note).

Register them in the `HandlerRegistry` (most-specific first, generic last).

## Safety

`ShellCommandHandler` runs arbitrary commands — keep it behind clear intent and never
run destructive commands silently. For now it is deliberately gated to a small
read-only allowlist (`git status`, `ls`, `pwd`, `date`, `whoami`, `echo`, Swift version)
and rejects shell chaining/redirection. Broaden this only when trust UX exists.

## Latency

- `browserSearch` is a single `NSWorkspace.open` — well under the 100 ms dispatch budget.
- Implement **speculative prefetch** (see [`../latency.md`](../latency.md)): on a
  high-confidence `open…`/`search…` Tier-0 match, start the launch as soon as the slot is
  known.

## Acceptance

- Hold hotkey, say "search best restaurants in SF" → release → browser opens Google
  results. End-to-end feels sub-second; log `submit → dispatch-done` < 150 ms (excluding
  the browser's own launch).
- "open Figma" launches/focuses Figma.
- `swift build` green, `CasprFlowChecks` passes (URL-builder + name-resolution asserts).

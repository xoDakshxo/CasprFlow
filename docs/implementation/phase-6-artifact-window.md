# Phase 6 — Artifact window + SQL agent (the "Prachi" flow)

## Goal

"Get this doc ready for Prachi" → a skill-loaded SQL agent spins up, writes the query,
**streams it into a floating always-on-top artifact window**, the user clicks **Run**,
it executes against ClickHouse and confirms done. This phase builds the reusable
**artifact window primitive** and the SQL handler that uses it.

The artifact window is a general primitive: any "draft something, then let me act on it"
flow uses it (SQL, shell scripts, generated text, diffs).

## Build

- `Sources/CasprFlowCore/Exec/ArtifactWindow.swift` — a floating always-on-top panel
  (built on `FloatingPanel`) that streams text as it arrives and exposes actions
  (Run / Copy / Dismiss). Reusable, content-agnostic.
- `Sources/CasprFlowCore/Handlers/SQLArtifactHandler.swift` — `.sqlArtifact` → run a
  skill-loaded SQL agent → stream tokens into the artifact window → on Run, execute.

```swift
@MainActor
final class ArtifactWindow {
    init(title: String, actions: [ArtifactAction])
    func show()
    func append(_ chunk: String)      // stream tokens in
    func setStatus(_ text: String)    // "running…", "done", error
}
struct ArtifactAction { let title: String; let run: () async -> Void }   // e.g. Run, Copy
```

## SQL agent

- System prompt is **skill-loaded**: include the ClickHouse schema/conventions and the
  user's intent so the agent writes a correct query. The agent must fully understand the
  task — give it the table context, the goal ("ready for Prachi" → what columns/filters),
  and the dialect (ClickHouse SQL).
- Stream the generated SQL into the artifact window as it's produced (`LLMClient` — or a
  streaming variant; add streaming to the client if needed).
- **Run** action: execute via `ShellRunner` calling `clickhouse-client` (connection from
  config/env), capture the result, show it + "done" in the artifact window. Or, per
  the user's environment, paste into an open ClickHouse client. Keep the execution path
  configurable; do not hardcode credentials.

## Reuse

- `FloatingPanel` (always-on-top via `.floating` level) — the window shell.
- `ShellRunner` (phase 3) — run `clickhouse-client`.
- `PasteService` — alternative paste-into-GUI execution path.
- `CasprFlowLogoMark` — streaming/working spinner in the window.

## Latency

Drafting streams (show tokens as they arrive — perceived latency stays low even if total
generation takes a couple seconds). Execution is a local CLI call. Keep the window
prewarmable if it becomes a hot path.

## Acceptance

- A spoken doc/SQL request opens the artifact window and streams a query into it.
- Clicking Run executes it and shows the result + a done state.
- The artifact window is reusable for non-SQL content (verify with a second simple use).
- `swift build` green, `CasprFlowChecks` passes.

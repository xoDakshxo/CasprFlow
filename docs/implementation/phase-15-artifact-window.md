# Phase 15 — Artifact window + draft/paste capabilities (the "Prachi" flow)

## Goal

Build the reusable **floating artifact window** primitive and the capabilities that use
it: `draft_artifact` (stream model output into an always-on-top panel, expose Run/Copy/
Dismiss) and `paste_text` (draft into the focused app — **never auto-send**). This makes
the reference flow real — "get this doc ready for Prachi" → a skill-loaded agent streams a
SQL query into the window, the user clicks Run — while staying content-agnostic (D7, D8).

## Build

`Sources/CasprFlowCore/Exec/ArtifactWindow.swift`:

```swift
public struct ArtifactAction: Sendable {
    public let title: String                    // "Run", "Copy", "Dismiss"
    public let isConsequential: Bool            // Run/Send → confirm-styled
    public let perform: @Sendable () async -> Void
}

@MainActor
public final class ArtifactWindow {
    public init(title: String, actions: [ArtifactAction])
    public func show()
    public func append(_ chunk: String)         // stream tokens as they arrive
    public func setStatus(_ text: String)        // "drafting…", "running…", "done", error
    public func dismiss()
}
```

Built on the kept `FloatingPanel` shell at `.floating` level (always-on-top), reusing
`CasprFlowLogoMark` for the streaming/working spinner. **Prewarm-friendly:** allocate
lazily but keep a single reusable instance if it becomes a hot path (latency tactic).

`Sources/CasprFlowCore/Capabilities/Builtin/DraftArtifactCapability.swift`:

```swift
public struct DraftArtifactCapability: Capability {
    public let name = "draft_artifact"
    public let summary = "Draft content (a SQL query, a script, a message) into a floating \
window the user can review and run. Use for 'draft/prepare X' tasks; never executes \
outward actions automatically."
    public let sideEffect: SideEffect = .local
    public var parameters: CapabilitySchema { .init(parameters: [
        .init(name: "request", type: "string", description: "What to draft", required: true),
        .init(name: "kind", type: "string", description: "sql | shell | text (default text)", required: false)
    ]) }
    // execute: open window → stream tokens from the (skill-loaded) model → wire Run.
}
```

`Sources/CasprFlowCore/Capabilities/Builtin/PasteTextCapability.swift`:

```swift
public struct PasteTextCapability: Capability {
    public let name = "paste_text"
    public let summary = "Paste a drafted message/text into the focused app. The user sends."
    public let sideEffect: SideEffect = .confirm   // outward → always confirm, never send
    // execute: confirm → PasteService.paste(text). Stops there. Does not press send.
}
```

### Streaming

- `draft_artifact` streams tokens into the window as they arrive — perceived latency stays
  low even if total generation is a couple seconds. If `LLMClient` lacks streaming, add a
  streaming variant (SSE) used **only** here; the planner/fast-path stay on the
  non-streaming small-output path.
- The system prompt for a `kind:sql` draft is **skill-loaded**: include the schema/dialect
  context and the user's intent so the query is correct. Keep credentials/connection out
  of code — read from config/env. The **Run** action executes via `ShellRunner`
  (`clickhouse-client`) or pastes into an open client; keep the execution path
  configurable, and Run is `isConsequential` → confirm-styled.

### Never auto-send (enforced)

- `paste_text` is `.confirm` and **pastes only** — it must not synthesize a send keystroke.
- Artifact `Run`/send-style actions are `isConsequential` and route through the confirm
  gate. The window's default-focused action is non-destructive.

## Reuse

- `FloatingPanel`, `CasprFlowLogoMark`, `PasteService`, `ShellRunner`, `LLMClient`, the
  confirm gate from phase 11.

## Latency budget

- Window show: `< 16 ms` if prewarmed (don't allocate on a hot path). Drafting streams, so
  first-token-visible is the perceived metric — keep it fast; total generation may be
  seconds.
- `paste_text`: `< 100 ms` after confirm.

## Acceptance

- `swift build` green; `CasprFlowChecks` passes.
- New `CasprFlowChecks` assertions (pure/view-model logic, no live model):
  - The artifact view-model accumulates streamed chunks in order and tracks status.
  - `paste_text` is classified `.confirm`; with `confirm → false` it does not paste.
  - An artifact `Run` action is flagged `isConsequential` and routes through confirm.
  - The never-send invariant: `paste_text.execute` calls paste but no send-key path
    exists (assert via a `PasteService` spy that only `paste` is called).
- Manual smoke: a spoken "draft a query for …" opens the window and streams a query; Run
  asks confirm then executes; a second non-SQL "draft a message …" reuses the same window
  primitive; "reply to X with Y" pastes a draft and stops.

## Out of scope

- A full SQL/skill framework — `draft_artifact` ships the primitive + one working `kind`.
  Broader skills are later capabilities over the same window.

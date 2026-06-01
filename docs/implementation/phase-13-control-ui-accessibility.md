# Phase 13 — control_ui: Accessibility driver (AX-first)

## Goal

The first, fast, local half of the tier-3 escape hatch. Build `AccessibilityDriver` over
the macOS `AXUIElement` API and the `control_ui` capability that uses it: read the focused
app's element tree, find a target by role/title/identifier/value, and act
(`AXPress`, set `AXValue`). This reaches apps that have **no** URL scheme / AppleScript /
CLI — without pixels, without a model, in milliseconds (D2, D11). Vision (phase 14) is the
fallback *within* this capability; this phase ships AX-only and reports honestly when AX
can't reach a target.

## Build

`Sources/CasprFlowCore/ControlUI/AccessibilityDriver.swift`:

```swift
public struct AXNode: Equatable, Sendable {
    public let role: String          // AXButton, AXTextField, AXStaticText, …
    public let title: String?
    public let value: String?
    public let identifier: String?   // AXIdentifier when present
    public let frame: CGRect
    public let path: [Int]           // index path from root, for re-resolution
}

public struct AXSelector: Equatable, Sendable {
    public let role: String?
    public let titleContains: String?
    public let identifier: String?
    public let valueContains: String?
}

@MainActor
public final class AccessibilityDriver {
    public init()
    public var isTrusted: Bool { get }                       // AXIsProcessTrusted
    public func focusedApplication() -> AXUIElement?
    public func snapshot(of app: AXUIElement, maxNodes: Int = 400) -> [AXNode]   // flattened tree
    public func find(_ selector: AXSelector, in nodes: [AXNode]) -> AXNode?
    public func press(_ node: AXNode, in app: AXUIElement) throws                 // AXPress
    public func setValue(_ value: String, on node: AXNode, in app: AXUIElement) throws
    public func windows(of app: AXUIElement) -> [AXNode]
}
```

`Sources/CasprFlowCore/Capabilities/Builtin/ControlUICapability.swift`:

```swift
public struct ControlUICapability: Capability {
    public let name = "control_ui"
    public let summary = "Operate an app's UI directly (click a button, type into a field) \
when no URL scheme, AppleScript, or CLI can do it. Slower; use only as a last resort."
    public let sideEffect: SideEffect = .local   // some actions confirm (see below)
    public var parameters: CapabilitySchema { .init(parameters: [
        .init(name: "app", type: "string", description: "Target app name (optional; defaults to frontmost)", required: false),
        .init(name: "instruction", type: "string", description: "What to do, in plain language", required: true)
    ]) }
    // Phase 13: AX path only.
}
```

### `control_ui` AX path (this phase)

1. Resolve the target app (named arg → `AppLauncher`/`NSRunningApplication`, else
   frontmost). Ensure Accessibility trust; if not trusted, route the user to the existing
   permission guide and report.
2. `snapshot` the app's element tree (bounded `maxNodes`).
3. Turn the plain-language `instruction` into an `AXSelector` + action. **Phase 13 keeps
   this deterministic/heuristic** where possible (match instruction keywords against node
   titles/roles); a model-assisted selector is acceptable but the **selector-matching and
   tree-flattening logic must be pure and unit-tested**. (The model-driven target picking
   can lean on the planner/agent that called `control_ui`.)
4. `find` the node; `press` or `setValue`. Re-resolve by `path` if the tree changed.
5. If no node matches → return a failure with the tree summary (so the caller/agent can
   decide to fall to vision in phase 14). **Do not** guess-click.

### Side-effect classification

- Read/snapshot = `.readOnly`. Press/setValue on a clearly-outward control (a "Send",
  "Delete", "Pay" button — match by title) escalate to **confirm** before acting (D8/D13).
  Keep the outward-verb list small and at the capability edge, not in the core.

## Reuse

- The existing **Accessibility permission** stack (`AccessibilityPermissionService`,
  `PermissionGuideController`, drag-into-Settings flow) — now load-bearing.
- `AppLauncher`/`NSRunningApplication` to resolve/focus the target app.
- `SelectionTextNormalizer`.

## Latency budget

- `snapshot` + `find` + act: **< 150 ms** for typical trees (bound `maxNodes`; don't walk
  unbounded). No network, no pixels.
- This is the *fast* half of tier 3 — keep it that way; the model is not in this loop
  unless the caller (agent) chose the selector.

## Acceptance

- `swift build` green; `CasprFlowChecks` passes.
- New `CasprFlowChecks` assertions (pure logic, no live app):
  - `find` matches a node by role + titleContains; returns nil when nothing matches.
  - `find` prefers `identifier` exact match over title substring when both present.
  - Tree-flattening produces stable `path` index-paths and respects `maxNodes`.
  - Outward-verb detection flags "Send"/"Delete" titles for the confirm escalation.
- Manual smoke (requires Accessibility permission): a `control_ui{instruction:"click
  Compose"}` against a real app (e.g. Mail) presses the right button; an unreachable
  target returns a clear failure with a tree summary (no wrong click).

## Out of scope

- Vision / screenshots / `CGEvent` synthesis (phase 14). Phase 13 fails gracefully when
  AX can't reach the element; phase 14 adds the fallback.

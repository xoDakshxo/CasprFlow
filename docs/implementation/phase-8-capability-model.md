# Phase 8 — Capability model + registry (foundations)

## Goal

Replace the fixed-enum `Intent` / `ActionHandler` coupling with the **Capability** model:
one typed-tool protocol that serves both the deterministic fast-path and the planner.
Migrate the existing executors (`open_url`, `open_app`, `web_search`, `run_shell`,
`run_applescript`, `spawn_swarm`) onto it behind a shim so **every command that works
today still works after this phase** — no behavior change yet, just the new spine.

This phase ships no new user-facing ability. It exists so phases 9–16 have a stable seam.

## Build

New directory `Sources/CasprFlowCore/Capabilities/`:

- `Capability.swift` — the protocol + `CapabilityCall`, `CapabilityResult`, `SideEffect`,
  `CapabilitySchema`, `CapabilityParameter`.
- `JSONValue.swift` — a small `Codable`/`Equatable`/`Sendable` JSON value enum used for
  capability arguments and structured results.
- `CapabilityRegistry.swift` — register capabilities, build the planner **catalog**,
  validate + dispatch a `CapabilityCall`.
- `ExecutionContext.swift` — per-run state passed into `execute`.
- `Capabilities/Builtin/` — thin wrappers over the kept executors:
  `OpenURLCapability`, `OpenAppCapability`, `WebSearchCapability`, `RunShellCapability`,
  `RunAppleScriptCapability`, `SpawnSwarmCapability`.

### Types (target shape)

```swift
public enum JSONValue: Equatable, Sendable {
    case string(String), number(Double), bool(Bool)
    case array([JSONValue]), object([String: JSONValue]), null
}
// Codable both ways; helpers: .stringValue, .intValue; build from/to [String: Any].

public enum SideEffect: String, Sendable {
    case readOnly   // observe only (read AX tree, run `git status`)
    case local      // changes local state, reversible-ish (open app, paste draft)
    case confirm    // outward/irreversible (send, destructive shell) → user must approve
}

public struct CapabilityParameter: Sendable {
    public let name: String
    public let type: String         // "string" | "number" | "boolean"
    public let description: String
    public let required: Bool
}
public struct CapabilitySchema: Sendable {
    public let parameters: [CapabilityParameter]
    public func jsonSchema() -> [String: Any]   // strict object schema for the planner
}

public struct CapabilityCall: Equatable, Sendable {
    public let capability: String
    public let arguments: [String: JSONValue]
    public func string(_ key: String) -> String?   // convenience accessors
}

public struct CapabilityResult: Sendable {
    public let ok: Bool
    public let message: String?           // HUD-facing
    public let observation: String?       // fed back to a TaskAgent (phase 12)
    public let data: [String: JSONValue]  // structured output for later steps
    public static func success(_ message: String?) -> CapabilityResult
    public static func failure(_ message: String) -> CapabilityResult
    public var actionResult: ActionResult // reduce to the kept HUD type
}

public protocol Capability: Sendable {
    var name: String { get }
    var summary: String { get }
    var parameters: CapabilitySchema { get }
    var sideEffect: SideEffect { get }
    func fastMatch(_ text: String) -> CapabilityCall?   // default nil
    func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult
}
public extension Capability { func fastMatch(_ text: String) -> CapabilityCall? { nil } }
```

```swift
public struct CapabilityDescriptor: Sendable {   // one catalog entry for the planner
    public let name: String
    public let summary: String
    public let sideEffect: SideEffect
    public let schema: [String: Any]
}

@MainActor
public final class CapabilityRegistry {
    public init(_ capabilities: [any Capability])
    public func capability(named: String) -> (any Capability)?
    public func catalog() -> [CapabilityDescriptor]        // for the planner (phase 10)
    public func fastMatch(_ text: String) -> CapabilityCall?  // first capability that claims it
    public func dispatch(_ call: CapabilityCall, context: ExecutionContext) async -> CapabilityResult
    // dispatch: unknown name → failure; validate required args against schema → failure if missing
}
```

```swift
public struct ExecutionContext: Sendable {
    public let rawText: String                       // the full transcript
    public let frontmostAppBundleID: String?         // for capabilities that need focus
    public var priorResults: [CapabilityResult]      // outputs of earlier steps in the plan
    public let clarify: @Sendable (String) async -> String?   // ask_user hook (phase 11)
    public let confirm: @Sendable (String) async -> Bool      // confirm hook (phase 11)
    // Phase 8: clarify/confirm can be no-op stubs; wired for real in phase 11.
}
```

### Builtin capability migration (no logic rewrite)

Each builtin wraps the **existing** executor and reuses the **existing** slot/builder
logic. Example shape:

```swift
public struct OpenAppCapability: Capability {
    public let name = "open_app"
    public let summary = "Launch or focus a macOS application by name."
    public let sideEffect: SideEffect = .local
    public var parameters: CapabilitySchema { .init(parameters: [
        .init(name: "app", type: "string", description: "App name, e.g. Figma", required: true)
    ]) }
    private let launcher = AppLauncher()
    public func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult {
        guard let app = call.string("app") else { return .failure("Missing app name.") }
        return try await launcher.open(app).capabilityResult   // ActionResult → CapabilityResult
    }
}
```

`fastMatch` is **not** implemented in phase 8 (that is phase 9's job — keep this phase
focused on the model). For this phase, dispatch is exercised via direct `CapabilityCall`s
in checks, and the live app keeps using the existing router/registry unchanged.

### Keep the app green without swapping the brain yet

Do **not** rewire `AppCoordinator` to the new path in this phase. The existing
`TieredIntentRouter` + `HandlerRegistry` stay wired and working. Phase 8 adds the
capability layer **alongside** them and proves it in `CasprFlowChecks`. Phase 11 performs
the swap. (Rationale: keep each PR small and the app shippable at every step.)

## Reuse

- Executors: `URLSchemeLauncher`, `AppLauncher`, `ShellRunner`, `AppleScriptRunner`,
  `SwarmHost`/`SwarmSpecBuilder`, `BrowserSearchURLBuilder`, `ShellCommandPolicy`,
  `ProjectResolver` — all unchanged, wrapped.
- `ActionResult`, `SelectionTextNormalizer` — kept.

## Latency budget

No hot-path change. `CapabilityRegistry.dispatch` validation must be allocation-light
(`< 0.5 ms` for arg validation). `catalog()` may be built lazily/cached — it is only used
on the planner miss path, never tier 1.

## Acceptance

- `swift build` green; `swift run CasprFlowChecks` passes.
- New `CasprFlowChecks` assertions:
  - `JSONValue` round-trips through `Codable` and `[String: Any]` both ways.
  - `CapabilitySchema.jsonSchema()` emits a strict closed object with `required` listing
    only required params.
  - `CapabilityRegistry.dispatch` with an unknown name → `ok == false`.
  - `dispatch` with a missing required arg → `ok == false` with a clear message.
  - A stub read-only capability dispatches and returns its `observation`/`data`.
  - `OpenAppCapability`/`RunShellCapability` produce the same `ActionResult` shape as the
    legacy handler for an equivalent call (reuse the existing builder assertions).
- The live app is unchanged (still routes via the legacy path) — manual smoke: "open
  Linear", "search …" still work.

## Out of scope

- No `fastMatch`, no planner, no orchestrator swap, no new user ability. Those are
  phases 9–11.

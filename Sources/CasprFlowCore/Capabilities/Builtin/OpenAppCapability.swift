import Foundation

public struct OpenAppCapability: Capability {
    public let name = "open_app"
    public let summary = "Launch or focus a macOS application by name."
    public let sideEffect: SideEffect = .local

    public var parameters: CapabilitySchema {
        CapabilitySchema(parameters: [
            CapabilityParameter(
                name: "app",
                type: "string",
                description: "App name, e.g. Figma.",
                required: true
            )
        ])
    }

    private let launcher: any AppLaunching

    public init(launcher: any AppLaunching = AppLauncher()) {
        self.launcher = launcher
    }

    public func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult {
        guard let app = call.string("app") else {
            return .failure("Missing app name.")
        }

        return try await launcher.open(app).capabilityResult
    }
}

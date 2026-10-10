import Foundation

public struct OpenURLCapability: Capability {
    public let name = "open_url"
    public let summary = "Open an absolute URL or deep link."
    public let sideEffect: SideEffect = .local

    public var parameters: CapabilitySchema {
        CapabilitySchema(parameters: [
            CapabilityParameter(
                name: "url",
                type: "string",
                description: "Absolute URL or deep link to open.",
                required: true
            )
        ])
    }

    private let launcher: any URLSchemeLaunching

    public init(launcher: any URLSchemeLaunching = URLSchemeLauncher()) {
        self.launcher = launcher
    }

    public func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult {
        guard let rawURL = call.string("url"),
              let url = URL(string: rawURL) else {
            return .failure("Missing URL.")
        }

        _ = try await launcher.open(url)
        return .success("Opened URL")
    }
}

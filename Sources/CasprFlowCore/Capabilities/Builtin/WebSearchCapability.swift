import Foundation

public struct WebSearchCapability: Capability {
    public let name = "web_search"
    public let summary = "Open a Google search for a query."
    public let sideEffect: SideEffect = .local

    public var parameters: CapabilitySchema {
        CapabilitySchema(parameters: [
            CapabilityParameter(
                name: "query",
                type: "string",
                description: "Search query.",
                required: true
            )
        ])
    }

    private let launcher: any URLSchemeLaunching

    public init(launcher: any URLSchemeLaunching = URLSchemeLauncher()) {
        self.launcher = launcher
    }

    public func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult {
        guard let query = call.string("query"),
              let url = BrowserSearchURLBuilder.googleSearchURL(query: query) else {
            return .failure("Missing search query.")
        }

        _ = try await launcher.open(url)
        return .success("Opened Google")
    }
}

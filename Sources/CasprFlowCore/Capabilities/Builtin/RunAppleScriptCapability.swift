import Foundation

public struct RunAppleScriptCapability: Capability {
    public let name = "run_applescript"
    public let summary = "Run an AppleScript through osascript."
    public let sideEffect: SideEffect = .confirm

    public var parameters: CapabilitySchema {
        CapabilitySchema(parameters: [
            CapabilityParameter(
                name: "script",
                type: "string",
                description: "AppleScript source to run.",
                required: true
            ),
            CapabilityParameter(
                name: "language",
                type: "string",
                description: "Optional osascript language, e.g. JavaScript.",
                required: false
            )
        ])
    }

    private let runner: any AppleScriptRunning
    private let timeout: TimeInterval

    public init(runner: any AppleScriptRunning = AppleScriptRunner(), timeout: TimeInterval = 10) {
        self.runner = runner
        self.timeout = timeout
    }

    public func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult {
        guard let script = call.string("script"),
              SelectionTextNormalizer.clean(script) != nil else {
            return .failure("Missing AppleScript.")
        }

        let result = try await runner.run(
            script,
            language: call.string("language"),
            timeout: timeout
        )
        let output = SelectionTextNormalizer.clean(result.output)
        return .success(output ?? "AppleScript completed.")
    }
}

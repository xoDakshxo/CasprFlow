import Foundation

public struct RunShellCapability: Capability {
    public let name = "run_shell"
    public let summary = "Run an allowlisted shell command."
    public let sideEffect: SideEffect = .readOnly

    public var parameters: CapabilitySchema {
        CapabilitySchema(parameters: [
            CapabilityParameter(
                name: "command",
                type: "string",
                description: "Allowlisted shell command to run.",
                required: true
            )
        ])
    }

    private let runner: any ShellRunning
    private let timeout: TimeInterval

    public init(runner: any ShellRunning = ShellRunner(), timeout: TimeInterval = 5) {
        self.runner = runner
        self.timeout = timeout
    }

    public func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult {
        guard let command = call.string("command"),
              let cleanedCommand = SelectionTextNormalizer.clean(command) else {
            return .failure("Missing shell command.")
        }

        guard ShellCommandPolicy.isAllowed(cleanedCommand) else {
            throw ShellRunnerError.rejected(cleanedCommand)
        }

        let result = try await runner.runShell(cleanedCommand, cwd: nil, timeout: timeout)
        guard result.exitCode == 0 else {
            return .failure(SelectionTextNormalizer.clean(result.stderr) ?? "Command failed.")
        }

        let output = SelectionTextNormalizer.clean(result.stdout)
        return .success(output ?? "Command completed.")
    }
}

import Foundation

public struct AppleScriptResult: Equatable, Sendable {
    public let output: String

    public init(output: String) {
        self.output = output
    }
}

public struct AppleScriptRunner: Sendable {
    private let shellRunner: ShellRunner

    public init(shellRunner: ShellRunner = ShellRunner()) {
        self.shellRunner = shellRunner
    }

    public func run(
        _ source: String,
        language: String? = nil,
        timeout: TimeInterval = 10
    ) async throws -> AppleScriptResult {
        var args: [String] = []
        if let language {
            args.append(contentsOf: ["-l", language])
        }
        args.append(contentsOf: ["-e", source])

        let result = try await shellRunner.run(
            "/usr/bin/osascript",
            args: args,
            timeout: timeout
        )

        guard result.exitCode == 0 else {
            throw ShellRunnerError.launchFailed(result.stderr)
        }

        return AppleScriptResult(output: result.stdout)
    }
}

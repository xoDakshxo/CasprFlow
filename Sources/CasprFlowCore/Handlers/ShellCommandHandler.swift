import Foundation

public struct ShellCommandHandler: ActionHandler {
    private let runner: ShellRunner
    private let timeout: TimeInterval

    public init(runner: ShellRunner = ShellRunner(), timeout: TimeInterval = 5) {
        self.runner = runner
        self.timeout = timeout
    }

    public func match(_ intent: Intent) -> Bool {
        intent.kind == .shell
    }

    public func execute(_ intent: Intent) async throws -> ActionResult {
        guard let command = intent.slots["command"],
              let cleanedCommand = SelectionTextNormalizer.clean(command) else {
            return ActionResult(ok: false, message: "Missing shell command.")
        }

        guard ShellCommandPolicy.isAllowed(cleanedCommand) else {
            throw ShellRunnerError.rejected(cleanedCommand)
        }

        let result = try await runner.runShell(cleanedCommand, timeout: timeout)
        guard result.exitCode == 0 else {
            return ActionResult(
                ok: false,
                message: SelectionTextNormalizer.clean(result.stderr) ?? "Command failed."
            )
        }

        let output = SelectionTextNormalizer.clean(result.stdout)
        return ActionResult(ok: true, message: output ?? "Command completed.")
    }
}

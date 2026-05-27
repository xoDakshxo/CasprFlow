import Foundation

public struct ShellResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum ShellRunnerError: Error, Equatable, LocalizedError, Sendable {
    case rejected(String)
    case timedOut(TimeInterval)
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .rejected(let command):
            return "Shell command blocked: \(command)"
        case .timedOut(let timeout):
            return "Shell command timed out after \(timeout)s."
        case .launchFailed(let message):
            return "Shell command failed to start: \(message)"
        }
    }
}

public enum ShellCommandPolicy {
    private static let allowedPrefixes = [
        "date",
        "echo",
        "git status",
        "ls",
        "pwd",
        "swift --version",
        "whoami"
    ]
    private static let blockedShellSyntax = [";", "&&", "||", "|", "`", "$(", ">", "<", "\n", "\r"]

    public static func isAllowed(_ command: String) -> Bool {
        guard let cleanedCommand = SelectionTextNormalizer.clean(command) else {
            return false
        }
        guard !blockedShellSyntax.contains(where: { cleanedCommand.contains($0) }) else {
            return false
        }

        let normalized = DeterministicRouter.normalize(cleanedCommand)
        return allowedPrefixes.contains { prefix in
            normalized == prefix || normalized.hasPrefix("\(prefix) ")
        }
    }
}

public struct ShellRunner: Sendable {
    public init() {}

    public func run(
        _ executable: String,
        args: [String] = [],
        cwd: URL? = nil,
        timeout: TimeInterval = 10
    ) async throws -> ShellResult {
        let box = ProcessBox()
        box.process.executableURL = URL(fileURLWithPath: executable)
        box.process.arguments = args
        box.process.currentDirectoryURL = cwd

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        box.process.standardOutput = stdoutPipe
        box.process.standardError = stderrPipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                box.process.terminationHandler = { process in
                    guard box.markCompleted() else { return }

                    let stdout = String(
                        data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? ""
                    let stderr = String(
                        data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? ""

                    continuation.resume(
                        returning: ShellResult(
                            exitCode: process.terminationStatus,
                            stdout: stdout,
                            stderr: stderr
                        )
                    )
                }

                do {
                    guard !Task.isCancelled else {
                        throw CancellationError()
                    }
                    try box.process.run()
                } catch {
                    if box.markCompleted() {
                        continuation.resume(
                            throwing: error is CancellationError
                                ? error
                                : ShellRunnerError.launchFailed(error.localizedDescription)
                        )
                    }
                    return
                }

                Task {
                    try? await Task.sleep(nanoseconds: Self.timeoutNanoseconds(timeout))
                    guard !Task.isCancelled else { return }
                    guard box.markCompleted() else { return }
                    box.terminateIfRunning()
                    continuation.resume(throwing: ShellRunnerError.timedOut(timeout))
                }
            }
        } onCancel: {
            box.terminateIfRunning()
        }
    }

    public func runShell(
        _ command: String,
        cwd: URL? = nil,
        timeout: TimeInterval = 10
    ) async throws -> ShellResult {
        try await run("/bin/zsh", args: ["-lc", command], cwd: cwd, timeout: timeout)
    }

    private static func timeoutNanoseconds(_ timeout: TimeInterval) -> UInt64 {
        let seconds = max(timeout, 0.1)
        return UInt64(seconds * 1_000_000_000)
    }
}

private final class ProcessBox: @unchecked Sendable {
    let process = Process()
    private let lock = NSLock()
    private var completed = false

    func markCompleted() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !completed else { return false }
        completed = true
        return true
    }

    func terminateIfRunning() {
        lock.lock()
        let shouldTerminate = process.isRunning
        lock.unlock()

        if shouldTerminate {
            process.terminate()
        }
    }
}

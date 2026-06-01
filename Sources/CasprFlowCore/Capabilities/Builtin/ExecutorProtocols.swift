import Foundation

public protocol AppLaunching: Sendable {
    @MainActor
    func open(_ name: String) async throws -> ActionResult
}

extension AppLauncher: AppLaunching {}

public protocol URLSchemeLaunching: Sendable {
    @MainActor
    @discardableResult
    func open(_ url: URL) throws -> Bool
}

extension URLSchemeLauncher: URLSchemeLaunching {}

public protocol ShellRunning: Sendable {
    func runShell(_ command: String, cwd: URL?, timeout: TimeInterval) async throws -> ShellResult
}

extension ShellRunner: ShellRunning {}

public protocol AppleScriptRunning: Sendable {
    func run(_ source: String, language: String?, timeout: TimeInterval) async throws -> AppleScriptResult
}

extension AppleScriptRunner: AppleScriptRunning {}

public protocol AgentToolPreflighting: Sendable {
    func validate(_ tool: SwarmAgentTool) async throws
}

extension AgentToolPreflight: AgentToolPreflighting {}

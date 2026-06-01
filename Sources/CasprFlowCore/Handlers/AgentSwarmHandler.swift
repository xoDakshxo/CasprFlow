import Foundation

public struct AgentSwarmHandler: ActionHandler {
    private let specBuilder: SwarmSpecBuilder
    private let host: any SwarmHost
    private let toolPreflight: AgentToolPreflight
    private let projectClarificationService: ProjectClarificationService

    public init(
        specBuilder: SwarmSpecBuilder = SwarmSpecBuilder(),
        host: any SwarmHost = GhosttyHost(),
        toolPreflight: AgentToolPreflight = AgentToolPreflight(),
        projectClarificationService: ProjectClarificationService = ProjectClarificationService()
    ) {
        self.specBuilder = specBuilder
        self.host = host
        self.toolPreflight = toolPreflight
        self.projectClarificationService = projectClarificationService
    }

    public func match(_ intent: Intent) -> Bool {
        intent.kind == .agentSwarm
    }

    public func execute(_ intent: Intent) async throws -> ActionResult {
        let tool = try SwarmAgentTool.from(slot: intent.slots["tool"])
        try await toolPreflight.validate(tool)

        let spec = try await buildSpecWithProjectClarification(from: intent)
        try await host.launch(spec)

        return ActionResult(
            ok: true,
            message: "Launched \(spec.panes.count) agents"
        )
    }

    private func buildSpecWithProjectClarification(from intent: Intent) async throws -> SwarmSpec {
        do {
            return try specBuilder.build(from: intent)
        } catch SwarmHostError.projectNeedsClarification(let spokenName, let candidates) {
            guard let resolvedURL = await projectClarificationService.clarifyProject(
                spokenName: spokenName,
                candidates: candidates
            ) else {
                throw SwarmHostError.projectNotFound(spokenName)
            }

            try specBuilder.projectResolver.saveAlias(spokenName, projectURL: resolvedURL)
            return try specBuilder.build(from: intent)
        } catch SwarmHostError.ambiguousProject(let spokenName, let candidates) {
            guard let resolvedURL = await projectClarificationService.clarifyProject(
                spokenName: spokenName,
                candidates: candidates
            ) else {
                throw SwarmHostError.ambiguousProject(spokenName, candidates)
            }

            try specBuilder.projectResolver.saveAlias(spokenName, projectURL: resolvedURL)
            return try specBuilder.build(from: intent)
        } catch SwarmHostError.projectNotFound(let spokenName) {
            guard let resolvedURL = await projectClarificationService.clarifyProject(
                spokenName: spokenName,
                candidates: []
            ) else {
                throw SwarmHostError.projectNotFound(spokenName)
            }

            try specBuilder.projectResolver.saveAlias(spokenName, projectURL: resolvedURL)
            return try specBuilder.build(from: intent)
        }
    }
}

public struct AgentToolPreflight: Sendable {
    private let shellRunner: ShellRunner

    public init(shellRunner: ShellRunner = ShellRunner()) {
        self.shellRunner = shellRunner
    }

    public func validate(_ tool: SwarmAgentTool) async throws {
        let result = try await shellRunner.run(
            tool.defaultPath,
            args: ["--version"],
            timeout: 3
        )
        guard result.exitCode == 0 else {
            throw SwarmHostError.commandFailed(
                SelectionTextNormalizer.clean(result.stderr) ?? "\(tool.rawValue) --version failed"
            )
        }
    }
}

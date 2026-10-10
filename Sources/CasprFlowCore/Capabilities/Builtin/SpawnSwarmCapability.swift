import Foundation

public struct SpawnSwarmCapability: Capability {
    public let name = "spawn_swarm"
    public let summary = "Launch terminal coding agents in panes for a repository task."
    public let sideEffect: SideEffect = .local

    public var parameters: CapabilitySchema {
        CapabilitySchema(parameters: [
            CapabilityParameter(
                name: "count",
                type: "number",
                description: "Number of agents to launch.",
                required: false
            ),
            CapabilityParameter(
                name: "task",
                type: "string",
                description: "Complete task framing to give every spawned agent.",
                required: false
            ),
            CapabilityParameter(
                name: "project",
                type: "string",
                description: "Spoken project or repository name.",
                required: false
            ),
            CapabilityParameter(
                name: "dir",
                type: "string",
                description: "Explicit working directory path.",
                required: false
            ),
            CapabilityParameter(
                name: "tool",
                type: "string",
                description: "Agent CLI tool, codex or claude.",
                required: false
            )
        ])
    }

    private let specBuilder: SwarmSpecBuilder
    private let host: any SwarmHost
    private let toolPreflight: any AgentToolPreflighting

    public init(
        specBuilder: SwarmSpecBuilder = SwarmSpecBuilder(),
        host: any SwarmHost = GhosttyHost(),
        toolPreflight: any AgentToolPreflighting = AgentToolPreflight()
    ) {
        self.specBuilder = specBuilder
        self.host = host
        self.toolPreflight = toolPreflight
    }

    public func execute(_ call: CapabilityCall, context: ExecutionContext) async throws -> CapabilityResult {
        let slots = Self.slots(from: call)
        let intent = Intent(
            kind: .agentSwarm,
            slots: slots,
            confidence: 1,
            rawText: context.rawText
        )

        let tool = try SwarmAgentTool.from(slot: slots["tool"])
        try await toolPreflight.validate(tool)

        let spec = try specBuilder.build(from: intent)
        try await host.launch(spec)

        return .success("Launched \(spec.panes.count) agents")
    }

    private static func slots(from call: CapabilityCall) -> [String: String] {
        var slots: [String: String] = [:]

        for key in ["task", "project", "dir", "tool"] {
            if let value = call.string(key) {
                slots[key] = value
            }
        }

        if let count = call.int("count") {
            slots["count"] = String(count)
        } else if let count = call.string("count") {
            slots["count"] = count
        }

        return slots
    }
}

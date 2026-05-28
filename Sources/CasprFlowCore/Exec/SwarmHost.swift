import Foundation

public struct SwarmPane: Equatable, Sendable {
    public let title: String
    public let command: String
    public let cwd: URL

    public init(title: String, command: String, cwd: URL) {
        self.title = title
        self.command = command
        self.cwd = cwd
    }
}

public struct SwarmSpec: Equatable, Sendable {
    public let name: String
    public let panes: [SwarmPane]

    public init(name: String, panes: [SwarmPane]) {
        self.name = name
        self.panes = panes
    }
}

public protocol SwarmHost: Sendable {
    func launch(_ spec: SwarmSpec) async throws
}

public enum SwarmHostError: Error, Equatable, LocalizedError, Sendable {
    case emptySpec
    case unsupportedTool(String)
    case missingTool(String)
    case missingApp(String)
    case projectNotFound(String)
    case projectNeedsClarification(String, [String])
    case ambiguousProject(String, [String])
    case commandFailed(String)
    case invalidLaunchURL(String)

    public var errorDescription: String? {
        switch self {
        case .emptySpec:
            return "No swarm panes were requested."
        case .unsupportedTool(let tool):
            return "Unsupported swarm tool: \(tool)."
        case .missingTool(let path):
            return "Swarm tool not found at \(path)."
        case .missingApp(let appName):
            return "\(appName) is not installed. Install \(appName) and retry the swarm."
        case .projectNotFound(let project):
            return "Could not resolve project: \(project)."
        case .projectNeedsClarification(let project, let matches):
            return "Project \(project) needs clarification: \(matches.joined(separator: ", "))."
        case .ambiguousProject(let project, let matches):
            return "Project \(project) matched multiple folders: \(matches.joined(separator: ", "))."
        case .commandFailed(let message):
            return "Swarm command failed: \(message)."
        case .invalidLaunchURL(let name):
            return "Could not build Warp launch URL for \(name)."
        }
    }
}

public enum SwarmAgentTool: String, Sendable {
    case claude
    case codex

    public static func from(slot: String?) throws -> SwarmAgentTool {
        guard let slot, let cleaned = SelectionTextNormalizer.clean(slot) else {
            return .codex
        }

        let normalized = DeterministicRouter.normalize(cleaned)
        guard let tool = SwarmAgentTool(rawValue: normalized) else {
            throw SwarmHostError.unsupportedTool(cleaned)
        }

        return tool
    }

    public var defaultPath: String {
        switch self {
        case .claude:
            return "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/claude"
        case .codex:
            return "/opt/homebrew/bin/codex"
        }
    }

    public func command(toolPath: String, prompt: String?) -> String {
        switch self {
        case .claude:
            guard let prompt, SelectionTextNormalizer.clean(prompt) != nil else {
                return ShellQuoter.quote(toolPath)
            }
            return "\(ShellQuoter.quote(toolPath)) -p \(ShellQuoter.quote(prompt))"
        case .codex:
            guard let prompt, SelectionTextNormalizer.clean(prompt) != nil else {
                return ShellQuoter.quote(toolPath)
            }
            return "\(ShellQuoter.quote(toolPath)) \(ShellQuoter.quote(prompt))"
        }
    }
}

public enum ShellQuoter {
    public static func quote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

public enum SwarmTaskSplitter {
    public static func slices(from value: String, expectedCount: Int) -> [String] {
        guard expectedCount > 1,
              let cleaned = SelectionTextNormalizer.clean(value) else {
            return []
        }

        let separated = cleaned.replacingOccurrences(
            of: #"(?:\s*,\s*|\s+\band\b\s+|\s+\bplus\b\s+)"#,
            with: "\n",
            options: .regularExpression
        )
        let rawParts = separated.split(separator: "\n").map(String.init)

        var parts = rawParts.compactMap { part -> String? in
            let trimmed = part.replacingOccurrences(
                of: #"^\s*(?:and|plus)\s+"#,
                with: "",
                options: .regularExpression
            )
            return SelectionTextNormalizer.clean(trimmed)
        }

        guard parts.count > 1 else { return [] }

        if parts.count > expectedCount {
            let head = Array(parts.prefix(expectedCount - 1))
            let tail = parts.dropFirst(expectedCount - 1).joined(separator: ", ")
            parts = head + [tail]
        }

        return parts
    }
}

public struct SwarmSpecBuilder: Sendable {
    private static let spokenCounts: [String: Int] = [
        "a": 1,
        "one": 1,
        "two": 2,
        "three": 3,
        "four": 4,
        "five": 5,
        "six": 6,
        "seven": 7,
        "eight": 8,
        "nine": 9,
        "ten": 10
    ]

    public let projectResolver: ProjectResolver
    public let maxAgents: Int
    public let validateToolExists: Bool
    private let toolPathProvider: @Sendable (SwarmAgentTool) -> String

    public init(
        projectResolver: ProjectResolver = ProjectResolver(),
        maxAgents: Int = 10,
        validateToolExists: Bool = true,
        toolPathProvider: @escaping @Sendable (SwarmAgentTool) -> String = { $0.defaultPath }
    ) {
        self.projectResolver = projectResolver
        self.maxAgents = maxAgents
        self.validateToolExists = validateToolExists
        self.toolPathProvider = toolPathProvider
    }

    public func build(from intent: Intent) throws -> SwarmSpec {
        let count = Self.agentCount(from: intent.slots["count"], maxAgents: maxAgents)
        let tool = try SwarmAgentTool.from(slot: intent.slots["tool"])
        let toolPath = toolPathProvider(tool)
        guard !validateToolExists || FileManager.default.isExecutableFile(atPath: toolPath) else {
            throw SwarmHostError.missingTool(toolPath)
        }

        let cwd = try projectResolver.resolve(
            project: intent.slots["project"],
            dir: intent.slots["dir"]
        )
        let safeTask = SelectionTextNormalizer.clean(intent.slots["task"])
        let taskSlices = safeTask.map {
            SwarmTaskSplitter.slices(from: $0, expectedCount: count)
        } ?? []

        let panes = (1...count).map { index in
            let ownedTask = taskSlices.indices.contains(index - 1)
                ? taskSlices[index - 1]
                : nil
            let prompt = safeTask.map {
                Self.agentPrompt(
                    rawIntent: intent.rawText,
                    task: $0,
                    cwd: cwd,
                    index: index,
                    count: count,
                    ownedTask: ownedTask
                )
            }
            let agentCommand = tool.command(toolPath: toolPath, prompt: prompt)
            let command = "cd \(ShellQuoter.quote(cwd.path)) && \(agentCommand)"

            return SwarmPane(
                title: Self.paneTitle(index: index, count: count, ownedTask: ownedTask),
                command: command,
                cwd: cwd
            )
        }

        return SwarmSpec(
            name: "\(cwd.lastPathComponent) Swarm",
            panes: panes
        )
    }

    public static func agentCount(from value: String?, maxAgents: Int = 10) -> Int {
        guard let value, let cleaned = SelectionTextNormalizer.clean(value) else {
            return 1
        }

        let normalized = DeterministicRouter.normalize(cleaned)
        let parsed = Int(normalized) ?? spokenCounts[normalized] ?? 1
        return min(max(parsed, 1), maxAgents)
    }

    public static func agentPrompt(
        rawIntent: String,
        task: String,
        cwd: URL,
        index: Int,
        count: Int,
        ownedTask: String? = nil
    ) -> String {
        var parts = [
            "CasprFlow spawned this unattended agent as part of a swarm.",
            "Full user intent: \(SelectionTextNormalizer.clean(rawIntent) ?? task).",
            "Repository context: \(cwd.lastPathComponent) at \(cwd.path).",
            "Overall goal: \(task).",
            "You are agent \(index) of \(count).",
        ]

        if let ownedTask = ownedTask,
           let cleanedOwnedTask = SelectionTextNormalizer.clean(ownedTask) {
            parts.append("Owned task: \(cleanedOwnedTask).")
        } else {
            parts.append("Own a distinct slice of the goal and avoid duplicating the other agents' likely work.")
        }

        parts.append(contentsOf: [
            "Make concrete progress in your slice, keep edits scoped, run relevant checks if you change code, and report what you changed plus any blockers when done."
        ])

        return parts.joined(separator: " ")
    }

    private static func paneTitle(index: Int, count: Int, ownedTask: String?) -> String {
        guard let ownedTask = SelectionTextNormalizer.clean(ownedTask) else {
            return "Agent \(index)/\(count)"
        }

        let clipped = ownedTask.count > 28
            ? "\(ownedTask.prefix(25))..."
            : ownedTask
        return "Agent \(index): \(clipped)"
    }
}

public enum WorkspaceDirectoryResolver {
    public static func defaultWorkspaceURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        bundleURL: URL? = Bundle.main.bundleURL
    ) -> URL {
        for key in ["CASPRFLOW_WORKSPACE", "CASPRFLOW_CWD"] {
            if let value = environment[key], let cleaned = SelectionTextNormalizer.clean(value) {
                return URL(fileURLWithPath: NSString(string: cleaned).expandingTildeInPath)
            }
        }

        if let bundleURL, bundleURL.pathComponents.contains(".build") {
            let buildDirectory = bundleURL.deletingLastPathComponent()
            return buildDirectory.deletingLastPathComponent()
        }

        if currentDirectory != "/" {
            return URL(fileURLWithPath: currentDirectory)
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }
}

public struct WarpLaunchConfigWriter: Sendable {
    public init() {}

    public func yaml(for spec: SwarmSpec) throws -> String {
        guard !spec.panes.isEmpty else {
            throw SwarmHostError.emptySpec
        }

        var lines = [
            "# Warp Launch Configuration",
            "---",
            "name: \(yamlQuote(spec.name))",
            "active_window_index: 0",
            "windows:",
            "  - active_tab_index: 0",
            "    tabs:",
            "      - title: \(yamlQuote(spec.name))",
            "        color: cyan",
            "        layout:"
        ]

        if spec.panes.count == 1 {
            appendPane(spec.panes[0], indent: "          ", to: &lines)
        } else {
            lines.append("          split_direction: vertical")
            lines.append("          panes:")
            for (index, pane) in spec.panes.enumerated() {
                lines.append("            - cwd: \(yamlQuote(pane.cwd.path))")
                lines.append("              title: \(yamlQuote(pane.title))")
                if index == 0 {
                    lines.append("              is_focused: true")
                }
                appendCommands(pane, indent: "              ", to: &lines)
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public func slug(for spec: SwarmSpec, timestamp: Date = Date()) -> String {
        let base = DeterministicRouter.normalize(spec.name)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let seconds = Int(timestamp.timeIntervalSince1970)
        return "\(base.isEmpty ? "casprflow-swarm" : base)-\(seconds)"
    }

    private func appendPane(_ pane: SwarmPane, indent: String, to lines: inout [String]) {
        lines.append("\(indent)cwd: \(yamlQuote(pane.cwd.path))")
        lines.append("\(indent)title: \(yamlQuote(pane.title))")
        appendCommands(pane, indent: indent, to: &lines)
    }

    private func appendCommands(_ pane: SwarmPane, indent: String, to lines: inout [String]) {
        lines.append("\(indent)commands:")
        lines.append("\(indent)  - exec: \(yamlQuote(pane.command))")
    }

    private func yamlQuote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }
}

public struct WarpHost: SwarmHost {
    private let launchConfigDirectory: URL
    private let launcher: URLSchemeLauncher
    private let writer: WarpLaunchConfigWriter

    public init(
        launchConfigDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".warp")
            .appendingPathComponent("launch_configurations"),
        launcher: URLSchemeLauncher = URLSchemeLauncher(),
        writer: WarpLaunchConfigWriter = WarpLaunchConfigWriter()
    ) {
        self.launchConfigDirectory = launchConfigDirectory
        self.launcher = launcher
        self.writer = writer
    }

    public func launch(_ spec: SwarmSpec) async throws {
        let slug = writer.slug(for: spec)
        let yaml = try writer.yaml(for: spec)
        try FileManager.default.createDirectory(
            at: launchConfigDirectory,
            withIntermediateDirectories: true
        )

        let configURL = launchConfigDirectory.appendingPathComponent("\(slug).yaml")
        try yaml.write(to: configURL, atomically: true, encoding: .utf8)

        guard let launchURL = Self.launchURL(forLaunchConfigurationAt: configURL) else {
            throw SwarmHostError.invalidLaunchURL(configURL.path)
        }

        NSLog("[CasprFlow] Wrote Warp launch config: %@", configURL.path)
        NSLog("[CasprFlow] Opening Warp launch URL: %@", launchURL.absoluteString)
        _ = try await MainActor.run {
            try launcher.open(launchURL)
        }
    }

    public static func launchURL(forLaunchConfigurationAt configURL: URL) -> URL? {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "/")

        guard let encodedPath = configURL.path.addingPercentEncoding(
            withAllowedCharacters: allowedCharacters
        ) else {
            return nil
        }

        return URL(string: "warp://launch/\(encodedPath)")
    }
}

public struct TmuxHost: SwarmHost {
    private let tmuxPath: String
    private let shellRunner: ShellRunner
    private let appleScriptRunner: AppleScriptRunner
    private let namer: TmuxSessionNamer

    public init(
        tmuxPath: String = "/opt/homebrew/bin/tmux",
        shellRunner: ShellRunner = ShellRunner(),
        appleScriptRunner: AppleScriptRunner = AppleScriptRunner(),
        namer: TmuxSessionNamer = TmuxSessionNamer()
    ) {
        self.tmuxPath = tmuxPath
        self.shellRunner = shellRunner
        self.appleScriptRunner = appleScriptRunner
        self.namer = namer
    }

    public func launch(_ spec: SwarmSpec) async throws {
        guard !spec.panes.isEmpty else {
            throw SwarmHostError.emptySpec
        }
        guard FileManager.default.isExecutableFile(atPath: tmuxPath) else {
            throw SwarmHostError.missingTool(tmuxPath)
        }

        let session = namer.sessionName(for: spec)
        let firstPane = spec.panes[0]

        _ = try await runTmux([
            "new-session",
            "-d",
            "-s", session,
            "-n", spec.name,
            "-c", firstPane.cwd.path
        ])

        var paneTargets = ["\(session):0.0"]
        for pane in spec.panes.dropFirst() {
            let result = try await runTmux([
                "split-window",
                "-t", "\(session):0",
                "-P",
                "-F", "#{pane_id}",
                "-c", pane.cwd.path,
            ])
            guard let paneID = SelectionTextNormalizer.clean(result.stdout) else {
                throw SwarmHostError.commandFailed("tmux did not return a pane id")
            }
            paneTargets.append(paneID)
        }

        _ = try await runTmux([
            "select-layout",
            "-t", "\(session):0",
            "tiled"
        ])
        _ = try await runTmux([
            "select-pane",
            "-t", "\(session):0.0"
        ])

        try await openTerminalAttached(to: session)

        for (pane, target) in zip(spec.panes, paneTargets) {
            try await sendCommand(pane.command, to: target)
        }
    }

    public static func attachCommand(tmuxPath: String, session: String) -> String {
        "\(ShellQuoter.quote(tmuxPath)) attach-session -t \(ShellQuoter.quote(session))"
    }

    private func runTmux(_ args: [String]) async throws -> ShellResult {
        let result = try await shellRunner.run(tmuxPath, args: args, timeout: 10)
        guard result.exitCode == 0 else {
            throw SwarmHostError.commandFailed(
                SelectionTextNormalizer.clean(result.stderr) ?? "tmux exited with \(result.exitCode)"
            )
        }
        return result
    }

    private func sendCommand(_ command: String, to target: String) async throws {
        _ = try await runTmux([
            "send-keys",
            "-t", target,
            "-l", command
        ])
        _ = try await runTmux([
            "send-keys",
            "-t", target,
            "Enter"
        ])
    }

    private func openTerminalAttached(to session: String) async throws {
        let command = Self.attachCommand(tmuxPath: tmuxPath, session: session)
        let source = """
        tell application "Terminal"
            activate
            do script \(Self.appleScriptString(command))
        end tell
        """
        _ = try await appleScriptRunner.run(source, timeout: 5)
    }

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

public struct TmuxSessionNamer: Sendable {
    public init() {}

    public func sessionName(for spec: SwarmSpec, timestamp: Date = Date()) -> String {
        let base = DeterministicRouter.normalize(spec.name)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(base.isEmpty ? "casprflow-swarm" : base)-\(Int(timestamp.timeIntervalSince1970))"
    }
}

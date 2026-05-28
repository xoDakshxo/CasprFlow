import Foundation

public struct GhosttyHost: SwarmHost {
    private let appName: String
    private let appleScriptRunner: AppleScriptRunner

    public init(
        appName: String = "Ghostty",
        appleScriptRunner: AppleScriptRunner = AppleScriptRunner()
    ) {
        self.appName = appName
        self.appleScriptRunner = appleScriptRunner
    }

    public func launch(_ spec: SwarmSpec) async throws {
        guard !spec.panes.isEmpty else {
            throw SwarmHostError.emptySpec
        }

        try await ensureGhosttyIsInstalled()
        let source = try Self.appleScript(for: spec, appName: appName)

        do {
            _ = try await appleScriptRunner.run(source, timeout: 10)
        } catch {
            throw SwarmHostError.commandFailed(error.localizedDescription)
        }
    }

    public static func appleScript(for spec: SwarmSpec, appName: String = "Ghostty") throws -> String {
        guard !spec.panes.isEmpty else {
            throw SwarmHostError.emptySpec
        }

        var lines = [
            "tell application \(AppleScriptQuoter.quote(appName))",
            "    activate",
            "    set cfg1 to new surface configuration",
            "    set initial working directory of cfg1 to \(AppleScriptQuoter.quote(spec.panes[0].cwd.path))",
            "    set win to new window with configuration cfg1",
            "    set tabRef to selected tab of win",
            "    set pane1 to focused terminal of tabRef",
            "    input text \(AppleScriptQuoter.quote(spec.panes[0].command)) to pane1",
            "    send key \"enter\" to pane1"
        ]

        if spec.panes.count > 1 {
            for index in 2...spec.panes.count {
                let pane = spec.panes[index - 1]
                let split = splitPlan(forPaneIndex: index)
                lines.append("    set cfg\(index) to new surface configuration")
                lines.append(
                    "    set initial working directory of cfg\(index) to \(AppleScriptQuoter.quote(pane.cwd.path))"
                )
                lines.append(
                    "    set pane\(index) to split pane\(split.targetPaneIndex) direction \(split.direction) with configuration cfg\(index)"
                )
                lines.append("    input text \(AppleScriptQuoter.quote(pane.command)) to pane\(index)")
                lines.append("    send key \"enter\" to pane\(index)")
            }
        }

        lines.append("    focus pane1")
        lines.append("end tell")
        return lines.joined(separator: "\n")
    }

    public static func splitPlan(forPaneIndex index: Int) -> GhosttySplitPlan {
        guard index > 1 else {
            return GhosttySplitPlan(targetPaneIndex: 1, direction: "right")
        }

        switch index {
        case 2:
            return GhosttySplitPlan(targetPaneIndex: 1, direction: "right")
        case 3:
            return GhosttySplitPlan(targetPaneIndex: 1, direction: "down")
        default:
            return GhosttySplitPlan(
                targetPaneIndex: index - 2,
                direction: index.isMultiple(of: 2) ? "down" : "right"
            )
        }
    }

    private func ensureGhosttyIsInstalled() async throws {
        do {
            _ = try await appleScriptRunner.run(
                "id of application \(AppleScriptQuoter.quote(appName))",
                timeout: 3
            )
        } catch {
            throw SwarmHostError.missingApp(appName)
        }
    }
}

public struct GhosttySplitPlan: Equatable, Sendable {
    public let targetPaneIndex: Int
    public let direction: String

    public init(targetPaneIndex: Int, direction: String) {
        self.targetPaneIndex = targetPaneIndex
        self.direction = direction
    }
}

public enum AppleScriptQuoter {
    public static func quote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }
}

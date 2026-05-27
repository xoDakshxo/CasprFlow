import Foundation

public struct OpenURLHandler: ActionHandler {
    private let launcher: URLSchemeLauncher

    public init(launcher: URLSchemeLauncher = URLSchemeLauncher()) {
        self.launcher = launcher
    }

    public func match(_ intent: Intent) -> Bool {
        intent.kind == .openURL
    }

    public func execute(_ intent: Intent) async throws -> ActionResult {
        guard let rawURL = intent.slots["url"],
              let url = URL(string: rawURL) else {
            return ActionResult(ok: false, message: "Missing URL.")
        }

        try await launcher.open(url)
        return ActionResult(ok: true, message: "Opened URL")
    }
}

import Foundation

public struct OpenAppHandler: ActionHandler {
    private let launcher: any AppLaunching

    public init(launcher: any AppLaunching = AppLauncher()) {
        self.launcher = launcher
    }

    public func match(_ intent: Intent) -> Bool {
        intent.kind == .openApp
    }

    public func execute(_ intent: Intent) async throws -> ActionResult {
        guard let appName = intent.slots["app"] else {
            return ActionResult(ok: false, message: "Missing app name.")
        }

        return try await launcher.open(appName)
    }
}

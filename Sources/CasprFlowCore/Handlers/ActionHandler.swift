import Foundation

public struct ActionResult: Equatable, Sendable {
    public let ok: Bool
    public let message: String?

    public init(ok: Bool, message: String? = nil) {
        self.ok = ok
        self.message = message
    }
}

public protocol ActionHandler: Sendable {
    func match(_ intent: Intent) -> Bool
    func execute(_ intent: Intent) async throws -> ActionResult
}

@MainActor
public final class HandlerRegistry {
    private let handlers: [any ActionHandler]

    public init(handlers: [any ActionHandler]) {
        self.handlers = handlers
    }

    public func dispatch(_ intent: Intent) async -> ActionResult {
        for handler in handlers where handler.match(intent) {
            do {
                return try await handler.execute(intent)
            } catch {
                return ActionResult(
                    ok: false,
                    message: "Action failed: \(error.localizedDescription)"
                )
            }
        }

        return ActionResult(
            ok: false,
            message: "No handler registered for \(intent.kind.rawValue)."
        )
    }
}

import AppKit
import Foundation

public enum URLSchemeLauncherError: Error, Equatable, LocalizedError, Sendable {
    case openFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let url):
            return "Could not open \(url)."
        }
    }
}

public struct URLSchemeLauncher: Sendable {
    public init() {}

    @MainActor
    @discardableResult
    public func open(_ url: URL) throws -> Bool {
        guard NSWorkspace.shared.open(url) else {
            throw URLSchemeLauncherError.openFailed(url.absoluteString)
        }

        return true
    }
}

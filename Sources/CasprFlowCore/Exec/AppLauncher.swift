import AppKit
import Foundation

public enum AppLauncherError: Error, Equatable, LocalizedError, Sendable {
    case notFound(String)
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let name):
            return "Could not find \(name)."
        case .launchFailed(let name):
            return "Could not open \(name)."
        }
    }
}

public enum AppNameResolver {
    private static let bundleIDsByName: [String: String] = [
        "arc": "company.thebrowser.Browser",
        "chrome": "com.google.Chrome",
        "figma": "com.figma.Desktop",
        "google chrome": "com.google.Chrome",
        "linear": "com.linear",
        "safari": "com.apple.Safari",
        "slack": "com.tinyspeck.slackmacgap",
        "warp": "dev.warp.Warp-Stable"
    ]

    public static func normalizedName(_ name: String) -> String {
        let cleaned = SelectionTextNormalizer.clean(name) ?? ""
        return cleaned
            .lowercased()
            .replacingOccurrences(of: #"(?i)\s+app$"#, with: "", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    public static func bundleIdentifier(for name: String) -> String? {
        bundleIDsByName[normalizedName(name)]
    }

    public static func candidateApplicationNames(for name: String) -> [String] {
        let normalized = normalizedName(name)
        guard !normalized.isEmpty else { return [] }

        let titled = normalized
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")

        return [normalized, titled, "\(titled).app"]
            .reduce(into: []) { candidates, candidate in
                if !candidates.contains(candidate) {
                    candidates.append(candidate)
                }
            }
    }
}

public struct AppLauncher: Sendable {
    public init() {}

    @MainActor
    public func open(_ name: String) async throws -> ActionResult {
        let normalizedName = AppNameResolver.normalizedName(name)
        guard !normalizedName.isEmpty else {
            throw AppLauncherError.notFound(name)
        }

        if let bundleID = AppNameResolver.bundleIdentifier(for: normalizedName),
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            try await openApplication(at: appURL, displayName: normalizedName)
            return ActionResult(ok: true, message: "Opened \(displayName(for: normalizedName))")
        }

        for candidate in AppNameResolver.candidateApplicationNames(for: normalizedName) {
            if let appURL = applicationURL(named: candidate) {
                try await openApplication(
                    at: appURL,
                    displayName: normalizedName
                )
                return ActionResult(ok: true, message: "Opened \(displayName(for: normalizedName))")
            }
        }

        throw AppLauncherError.notFound(displayName(for: normalizedName))
    }

    @MainActor
    private func openApplication(at url: URL, displayName: String) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func displayName(for normalizedName: String) -> String {
        normalizedName
            .split(separator: " ")
            .map { word in word.prefix(1).uppercased() + word.dropFirst() }
            .joined(separator: " ")
    }

    private func applicationURL(named candidate: String) -> URL? {
        let appName = candidate.hasSuffix(".app") ? candidate : "\(candidate).app"
        let searchDirectories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        for directory in searchDirectories {
            let url = directory.appendingPathComponent(appName)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}

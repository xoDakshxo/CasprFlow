import Foundation

public final class ProjectAliasStore: @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private let lock = NSRecursiveLock()

    public init(
        fileURL: URL = ProjectAliasStore.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func loadAliases() -> [String: URL] {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(ProjectAliasPayload.self, from: data) else {
            return [:]
        }

        return payload.aliases.reduce(into: [String: URL]()) { partial, pair in
            let key = ProjectResolver.normalizedName(pair.key)
            guard !key.isEmpty else { return }
            partial[key] = URL(fileURLWithPath: pair.value).standardizedFileURL
        }
    }

    public func saveAlias(_ alias: String, projectURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        let normalizedAlias = ProjectResolver.normalizedName(alias)
        guard !normalizedAlias.isEmpty else { return }

        var aliases = loadAliases().reduce(into: [String: String]()) { partial, pair in
            partial[pair.key] = pair.value.standardizedFileURL.path
        }
        aliases[normalizedAlias] = projectURL.standardizedFileURL.path

        let payload = ProjectAliasPayload(aliases: aliases)
        let data = try JSONEncoder.casprFlowPretty.encode(payload)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    public static func defaultFileURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/CasprFlow", isDirectory: true)
            .appendingPathComponent("project-aliases.json")
    }
}

private struct ProjectAliasPayload: Codable {
    let aliases: [String: String]
}

private extension JSONEncoder {
    static var casprFlowPretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

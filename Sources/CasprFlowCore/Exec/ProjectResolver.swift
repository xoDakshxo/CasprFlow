import Foundation

public struct ProjectResolver: Sendable {
    public let defaultProjectURL: URL
    public let aliases: [String: URL]
    public let searchRoots: [URL]
    public let aliasStore: ProjectAliasStore

    public init(
        defaultProjectURL: URL = WorkspaceDirectoryResolver.defaultWorkspaceURL(),
        aliases: [String: URL] = [:],
        searchRoots: [URL] = Self.defaultSearchRoots(),
        aliasStore: ProjectAliasStore = ProjectAliasStore()
    ) {
        self.defaultProjectURL = defaultProjectURL.standardizedFileURL
        self.searchRoots = searchRoots.map(\.standardizedFileURL)
        self.aliasStore = aliasStore

        var normalizedAliases = aliases.reduce(into: [String: URL]()) { partial, pair in
            let key = Self.normalizedName(pair.key)
            guard !key.isEmpty else { return }
            partial[key] = pair.value.standardizedFileURL
        }

        for alias in Self.defaultAliases(for: self.defaultProjectURL) {
            normalizedAliases[Self.normalizedName(alias)] = self.defaultProjectURL
        }
        for (alias, url) in aliasStore.loadAliases() {
            normalizedAliases[alias] = url
        }

        self.aliases = normalizedAliases
    }

    public func resolve(project projectSlot: String?, dir dirSlot: String? = nil) throws -> URL {
        if let dir = dirSlot, let cleanedDir = SelectionTextNormalizer.clean(dir) {
            return try resolveExplicitPath(cleanedDir)
        }

        guard let project = projectSlot,
              let cleanedProject = SelectionTextNormalizer.clean(project) else {
            return defaultProjectURL
        }

        if Self.isDefaultProjectReference(cleanedProject) {
            return defaultProjectURL
        }

        if Self.looksLikePath(cleanedProject) {
            return try resolveExplicitPath(cleanedProject)
        }

        let normalizedProject = Self.normalizedName(cleanedProject)
        if let alias = aliases[normalizedProject] {
            return alias
        }
        if let learnedAlias = aliasStore.loadAliases()[normalizedProject] {
            return learnedAlias
        }

        let matches = projectCandidates(for: normalizedProject)
        let exactMatches = matches.filter { $0.match == .exact }
        let uniqueExactMatches = Array(Set(exactMatches.map(\.url.path))).sorted()

        if uniqueExactMatches.count == 1, let match = uniqueExactMatches.first {
            return URL(fileURLWithPath: match).standardizedFileURL
        }

        if uniqueExactMatches.count > 1 {
            throw SwarmHostError.ambiguousProject(cleanedProject, uniqueExactMatches)
        }

        let fuzzyMatches = matches.filter { $0.match == .fuzzy }
        let uniqueFuzzyMatches = Array(Set(fuzzyMatches.map(\.url.path))).sorted()
        if !uniqueFuzzyMatches.isEmpty {
            throw SwarmHostError.projectNeedsClarification(cleanedProject, uniqueFuzzyMatches)
        }

        throw SwarmHostError.projectNotFound(cleanedProject)
    }

    public static func defaultSearchRoots(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        let code = homeDirectory.appendingPathComponent("Code")
        return [
            code,
            code.appendingPathComponent("ExternalProjects")
        ]
    }

    public static func normalizedName(_ value: String) -> String {
        var words = DeterministicRouter.normalize(value)
            .split(separator: " ")
            .map(String.init)

        if words.first == "the" {
            words.removeFirst()
        }

        while let last = words.last,
              ["repo", "repository", "project", "folder"].contains(last) {
            words.removeLast()
        }

        return words
            .joined()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }

    public static func isDefaultProjectReference(_ value: String) -> Bool {
        let normalized = DeterministicRouter.normalize(value)
        return [
            "this project",
            "this project folder",
            "current project",
            "current project folder",
            "this repo",
            "this repository",
            "current repo",
            "current repository",
            "this folder",
            "current folder"
        ].contains(normalized)
    }

    private static func defaultAliases(for url: URL) -> [String] {
        [
            url.lastPathComponent,
            "\(url.lastPathComponent) repo",
            "\(url.lastPathComponent) project"
        ]
    }

    private static func looksLikePath(_ value: String) -> Bool {
        value.hasPrefix("/") || value.hasPrefix("~") || value.hasPrefix(".")
    }

    private func resolveExplicitPath(_ value: String) throws -> URL {
        let expanded = NSString(string: value).expandingTildeInPath
        let url: URL
        if expanded.hasPrefix("/") {
            url = URL(fileURLWithPath: expanded)
        } else {
            url = URL(fileURLWithPath: expanded, relativeTo: defaultProjectURL)
        }

        let standardized = url.standardizedFileURL
        guard Self.isExistingDirectory(standardized) else {
            throw SwarmHostError.projectNotFound(value)
        }

        return standardized
    }

    public func saveAlias(_ alias: String, projectURL: URL) throws {
        try aliasStore.saveAlias(alias, projectURL: projectURL)
    }

    private func projectCandidates(for normalizedProject: String) -> [ProjectCandidate] {
        guard !normalizedProject.isEmpty else { return [] }

        var matches: [ProjectCandidate] = []
        for root in searchRoots {
            if Self.normalizedName(root.lastPathComponent) == normalizedProject,
               Self.isExistingDirectory(root) {
                matches.append(ProjectCandidate(url: root.standardizedFileURL, match: .exact))
            }

            for child in directoryCandidates(under: root, maxDepth: 3) {
                let childName = Self.normalizedName(child.lastPathComponent)
                if childName == normalizedProject {
                    matches.append(ProjectCandidate(url: child.standardizedFileURL, match: .exact))
                } else if Self.isLikelySameName(normalizedProject, childName) {
                    matches.append(ProjectCandidate(url: child.standardizedFileURL, match: .fuzzy))
                }
            }
        }

        return matches
    }

    private func directoryCandidates(under root: URL, maxDepth: Int) -> [URL] {
        guard maxDepth >= 0,
              Self.isExistingDirectory(root) else {
            return []
        }

        var candidates: [URL] = []
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return candidates
        }

        for child in children {
            guard Self.isExistingDirectory(child) else { continue }
            candidates.append(child.standardizedFileURL)

            let gitDirectory = child.appendingPathComponent(".git", isDirectory: true)
            if Self.isExistingDirectory(gitDirectory) {
                continue
            }

            candidates.append(contentsOf: directoryCandidates(under: child, maxDepth: maxDepth - 1))
        }

        return candidates
    }

    public static func isLikelySameName(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs.count >= 4, rhs.count >= 4 else { return false }
        let distance = levenshteinDistance(lhs, rhs)
        let maxLength = max(lhs.count, rhs.count)
        return distance <= 2 || Double(distance) / Double(maxLength) <= 0.22
    }

    public static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }

        var previous = Array(0...b.count)
        for (i, lhsCharacter) in a.enumerated() {
            var current = [i + 1]
            for (j, rhsCharacter) in b.enumerated() {
                let substitutionCost = lhsCharacter == rhsCharacter ? 0 : 1
                current.append(
                    min(
                        previous[j + 1] + 1,
                        current[j] + 1,
                        previous[j] + substitutionCost
                    )
                )
            }
            previous = current
        }

        return previous[b.count]
    }

    private static func isExistingDirectory(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}

private struct ProjectCandidate {
    enum Match {
        case exact
        case fuzzy
    }

    let url: URL
    let match: Match
}

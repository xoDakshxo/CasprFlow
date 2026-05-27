import Foundation

public enum BrowserSearchURLBuilder {
    public static func googleSearchURL(query: String) -> URL? {
        guard let cleanedQuery = SelectionTextNormalizer.clean(query) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: cleanedQuery)
        ]
        return components.url
    }
}

public struct BrowserSearchHandler: ActionHandler {
    private let launcher: URLSchemeLauncher

    public init(launcher: URLSchemeLauncher = URLSchemeLauncher()) {
        self.launcher = launcher
    }

    public func match(_ intent: Intent) -> Bool {
        intent.kind == .browserSearch
    }

    public func execute(_ intent: Intent) async throws -> ActionResult {
        guard let query = intent.slots["query"],
              let url = BrowserSearchURLBuilder.googleSearchURL(query: query) else {
            return ActionResult(ok: false, message: "Missing search query.")
        }

        try await launcher.open(url)
        return ActionResult(ok: true, message: "Opened Google")
    }
}

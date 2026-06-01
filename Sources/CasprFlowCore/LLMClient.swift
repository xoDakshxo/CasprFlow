import Foundation

/// Errors surfaced by the LLM connector.
public enum LLMError: Error, Equatable, Sendable {
    case missingAPIKey
    case invalidRequest
    case requestFailed(String)
    case emptyResponse
}

/// Resolved configuration for the OpenAI connector.
///
/// Loaded from (in priority order) environment variables, a project-local
/// `casprflow.config.local.json`, or `~/Library/Application Support/CasprFlow/config.json`.
public struct LLMConfig: Equatable, Sendable {
    /// Fast classifier model used by the intent router fallback.
    public static let defaultModel = "gpt-5.4-nano"

    public let apiKey: String?
    public let model: String
    public let reasoningEffort: String

    public init(apiKey: String?, model: String, reasoningEffort: String) {
        self.apiKey = apiKey
        self.model = model
        self.reasoningEffort = reasoningEffort
    }

    public static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> LLMConfig {
        let fileConfig = configURLs(fileManager: fileManager, homeDirectory: homeDirectory)
            .lazy
            .compactMap { url -> FileConfig? in
                guard fileManager.fileExists(atPath: url.path),
                      let data = try? Data(contentsOf: url) else {
                    return nil
                }
                return try? JSONDecoder().decode(FileConfig.self, from: data)
            }
            .first

        return LLMConfig(
            apiKey: clean(environment["OPENAI_API_KEY"]) ?? clean(fileConfig?.openaiAPIKey),
            model: clean(environment["OPENAI_MODEL"])
                ?? clean(fileConfig?.openaiModel)
                ?? defaultModel,
            reasoningEffort: normalizedReasoningEffort(
                clean(environment["OPENAI_REASONING_EFFORT"])
                    ?? clean(fileConfig?.openaiReasoningEffort)
                    ?? "low"
            )
        )
    }

    private static func configURLs(fileManager: FileManager, homeDirectory: URL) -> [URL] {
        var urls: [URL] = []
        let rootConfigName = "casprflow.config.local.json"

        urls.append(
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(rootConfigName)
        )

        var bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<6 {
            urls.append(bundleParent.appendingPathComponent(rootConfigName))
            bundleParent = bundleParent.deletingLastPathComponent()
        }

        urls.append(
            homeDirectory.appendingPathComponent("Library/Application Support/CasprFlow/config.json")
        )

        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedReasoningEffort(_ value: String) -> String {
        let normalized = value.lowercased()
        if normalized == "minimal" { return "low" }
        let allowed: Set<String> = ["none", "low", "medium", "high", "xhigh"]
        return allowed.contains(normalized) ? normalized : "low"
    }

    private struct FileConfig: Decodable {
        let openaiAPIKey: String?
        let openaiModel: String?
        let openaiReasoningEffort: String?

        enum CodingKeys: String, CodingKey {
            case openaiAPIKey = "openai_api_key"
            case openaiModel = "openai_model"
            case openaiReasoningEffort = "openai_reasoning_effort"
        }
    }
}

/// Minimal text-only client for the OpenAI Responses API.
///
/// Intended for the intent-router fallback: send a prompt, optionally request a
/// strict JSON schema via `textFormat`, get back the model's text output.
public final class LLMClient {
    private let config: LLMConfig
    private let endpoint: URL
    private let session: URLSession

    public init(
        config: LLMConfig = .load(),
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        session: URLSession = .shared
    ) {
        self.config = config
        self.endpoint = endpoint
        self.session = session
    }

    public var isConfigured: Bool {
        config.apiKey != nil
    }

    public var modelName: String {
        config.model
    }

    /// Warm the TLS connection to the endpoint so the first real request is not cold.
    /// Fire-and-forget; failures are ignored.
    public func preconnect() {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3
        session.dataTask(with: request).resume()
    }

    /// Send `prompt` and return the model's text output. When `textFormat` is a
    /// JSON-schema spec, the output is a strict JSON string matching that schema.
    public func complete(
        prompt: String,
        instructions: String,
        textFormat: [String: Any]? = nil,
        maxOutputTokens: Int = 256
    ) async throws -> String {
        guard let apiKey = config.apiKey else { throw LLMError.missingAPIKey }

        let body = Self.requestBody(
            model: config.model,
            prompt: prompt,
            instructions: instructions,
            textFormat: textFormat,
            maxOutputTokens: maxOutputTokens,
            reasoningEffort: config.reasoningEffort
        )

        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body) else {
            throw LLMError.invalidRequest
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.requestFailed("OpenAI returned a non-HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: responseData, encoding: .utf8)
                .map { String($0.prefix(220)) } ?? "No response body"
            throw LLMError.requestFailed("OpenAI request failed (\(httpResponse.statusCode)): \(message)")
        }

        guard let output = Self.extractOutputText(from: responseData),
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.emptyResponse
        }
        return output
    }

    public static func requestBody(
        model: String,
        prompt: String,
        instructions: String,
        textFormat: [String: Any]?,
        maxOutputTokens: Int,
        reasoningEffort: String
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "instructions": instructions,
            "input": [
                [
                    "role": "user",
                    "content": [["type": "input_text", "text": prompt]]
                ]
            ],
            "max_output_tokens": maxOutputTokens,
            "reasoning": ["effort": reasoningEffort],
            "store": false
        ]
        if let textFormat {
            body["text"] = ["format": textFormat]
        }
        return body
    }

    public static func extractOutputText(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let direct = object["output_text"] as? String,
           !direct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return direct
        }

        if let output = object["output"] as? [[String: Any]] {
            let text = output
                .flatMap { ($0["content"] as? [[String: Any]]) ?? [] }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }

        return nil
    }
}

extension LLMClient: LLMCompleting {}

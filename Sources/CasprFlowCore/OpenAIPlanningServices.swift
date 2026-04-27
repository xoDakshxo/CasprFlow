import Foundation

struct OpenAIPlanningConfig: Equatable, Sendable {
    static let defaultContextModel = "gpt-5.4-nano"
    static let defaultOutputModel = "gpt-5.4-mini"
    static let defaultFollowUpModel = "gpt-5.4-nano"

    let apiKey: String?
    let contextModel: String
    let outputModel: String
    let followUpModel: String
    let reasoningEffort: String
    let imageDetail: String

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> OpenAIPlanningConfig {
        let fileConfig = configURLs(fileManager: fileManager, homeDirectory: homeDirectory)
            .lazy
            .compactMap { url -> DeveloperConfig? in
                guard fileManager.fileExists(atPath: url.path),
                      let data = try? Data(contentsOf: url) else {
                    return nil
                }
                return try? JSONDecoder().decode(DeveloperConfig.self, from: data)
            }
            .first

        return OpenAIPlanningConfig(
            apiKey: clean(environment["OPENAI_API_KEY"])
                ?? clean(fileConfig?.openaiAPIKey),
            contextModel: clean(environment["OPENAI_CONTEXT_MODEL"])
                ?? clean(environment["OPENAI_MODEL"])
                ?? clean(fileConfig?.openaiContextModel)
                ?? clean(fileConfig?.openaiModel)
                ?? defaultContextModel,
            outputModel: clean(environment["OPENAI_OUTPUT_MODEL"])
                ?? clean(environment["OPENAI_MODEL"])
                ?? clean(fileConfig?.openaiOutputModel)
                ?? clean(fileConfig?.openaiModel)
                ?? defaultOutputModel,
            followUpModel: clean(environment["OPENAI_FOLLOWUP_MODEL"])
                ?? clean(environment["OPENAI_MODEL"])
                ?? clean(fileConfig?.openaiFollowUpModel)
                ?? clean(fileConfig?.openaiModel)
                ?? defaultFollowUpModel,
            reasoningEffort: normalizedReasoningEffort(
                clean(environment["OPENAI_REASONING_EFFORT"])
                    ?? clean(fileConfig?.openaiReasoningEffort)
                    ?? "low"
            ),
            imageDetail: clean(environment["OPENAI_IMAGE_DETAIL"])
                ?? clean(fileConfig?.openaiImageDetail)
                ?? "low"
        )
    }

    private static func configURLs(
        fileManager: FileManager,
        homeDirectory: URL
    ) -> [URL] {
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
            homeDirectory
                .appendingPathComponent("Library/Application Support/CasprFlow/config.json")
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

    private struct DeveloperConfig: Decodable {
        let openaiAPIKey: String?
        let openaiModel: String?
        let openaiContextModel: String?
        let openaiOutputModel: String?
        let openaiFollowUpModel: String?
        let openaiReasoningEffort: String?
        let openaiImageDetail: String?

        enum CodingKeys: String, CodingKey {
            case openaiAPIKey = "openai_api_key"
            case openaiModel = "openai_model"
            case openaiContextModel = "openai_context_model"
            case openaiOutputModel = "openai_output_model"
            case openaiFollowUpModel = "openai_followup_model"
            case openaiReasoningEffort = "openai_reasoning_effort"
            case openaiImageDetail = "openai_image_detail"
        }
    }
}

final class OpenAIContextBuilder: ContextBuilding {
    private let config: OpenAIPlanningConfig
    private let endpoint: URL
    private let session: URLSession

    init(
        config: OpenAIPlanningConfig = .load(),
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        session: URLSession = .shared
    ) {
        self.config = config
        self.endpoint = endpoint
        self.session = session
    }

    func buildContext(from capturePack: CapturePack) async throws -> ContextBrief {
        guard let apiKey = config.apiKey else {
            throw GenerationServiceError.missingAPIKey
        }

        let output = try await OpenAIResponsesClient(
            apiKey: apiKey,
            model: config.contextModel,
            endpoint: endpoint,
            session: session
        )
        .createResponse(
            prompt: Self.prompt(for: capturePack),
            textFormat: Self.contextJSONFormat,
            maxOutputTokens: 420,
            screenshots: Self.screenshots(for: capturePack),
            imageDetail: config.imageDetail,
            reasoningEffort: config.reasoningEffort,
            instructions: Self.instructions
        )

        return Self.parseContextBrief(output, fallbackCapturePack: capturePack)
    }

    static let instructions = "You are CasprFlow's build-context parser. Analyze the focused screenshot and compact app metadata only. Return structured context. Do not write replies, chips, drafts, advice, or user-facing copy."

    static func prompt(for capturePack: CapturePack) -> String {
        """
        # Task
        Build a compact ContextBrief for CasprFlow.

        Identify the active surface, latest target, speakers, current user position, useful snippets, ignored chrome, and missing context.

        Do not produce chips.
        Do not produce drafts.
        Do not write a response for the user.

        # CapturePack
        \(capturePack.debugJSON)

        Return strict JSON matching the schema.
        """
    }

    static func screenshots(for capturePack: CapturePack) -> [ScreenshotAttachment] {
        guard let screenshot = capturePack.screenshot,
              let data = screenshot.data,
              let mimeType = screenshot.mimeType else {
            return []
        }
        return [
            ScreenshotAttachment(
                metadata: screenshot.metadata,
                data: data,
                mimeType: mimeType
            )
        ]
    }

    static func requestBody(
        capturePack: CapturePack,
        config: OpenAIPlanningConfig
    ) -> [String: Any] {
        OpenAIResponsesClient.requestBody(
            model: config.contextModel,
            prompt: prompt(for: capturePack),
            textFormat: contextJSONFormat,
            maxOutputTokens: 420,
            screenshots: screenshots(for: capturePack),
            imageDetail: config.imageDetail,
            reasoningEffort: config.reasoningEffort,
            instructions: instructions
        )
    }

    static func parseContextBrief(
        _ output: String,
        fallbackCapturePack: CapturePack
    ) -> ContextBrief {
        guard let data = output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ContextBrief.self, from: data),
              !decoded.replyTargetSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallbackContextBrief(from: fallbackCapturePack)
        }
        return decoded
    }

    static func fallbackContextBrief(from capturePack: CapturePack) -> ContextBrief {
        let snippets = Array(capturePack.recent.map(\.text).prefix(3))
        let target = capturePack.selection
            ?? snippets.first
            ?? capturePack.focusedField?.valueSummary
            ?? "No clear reply target found."

        var flags: [String] = []
        if capturePack.screenshotDecision.action == .unavailable {
            flags.append("screenshot_unavailable")
        }
        if capturePack.visibleAXCandidates.isEmpty, capturePack.recent.isEmpty {
            flags.append("thin_text_context")
        }

        return ContextBrief(
            id: "context-\(capturePack.id)",
            captureID: capturePack.id,
            surfaceKind: capturePack.surfaceKind,
            replyTargetSummary: target,
            targetConfidence: min(capturePack.confidence, 0.45),
            relevantSnippets: snippets,
            speakerHints: [],
            targetDirection: capturePack.selection == nil ? .ambiguous : .selected,
            ignoredChromeSummary: "Used local capture summary because build-context output was unavailable.",
            missingContextFlags: flags,
            screenshotConfidence: capturePack.screenshot == nil ? 0 : min(capturePack.confidence, 0.45),
            sourceIDs: [capturePack.id]
        )
    }

    static var contextJSONFormat: [String: Any] {
        [
            "type": "json_schema",
            "name": "casprflow_context_brief",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "id": ["type": "string"],
                    "captureID": ["type": "string"],
                    "surfaceKind": ["type": "string", "enum": surfaceKinds],
                    "replyTargetSummary": ["type": "string"],
                    "targetConfidence": ["type": "number"],
                    "relevantSnippets": ["type": "array", "items": ["type": "string"]],
                    "speakerHints": ["type": "array", "items": ["type": "string"]],
                    "targetDirection": ["type": "string", "enum": targetDirections],
                    "ignoredChromeSummary": ["type": "string"],
                    "missingContextFlags": ["type": "array", "items": ["type": "string"]],
                    "screenshotConfidence": ["type": "number"],
                    "sourceIDs": ["type": "array", "items": ["type": "string"]]
                ],
                "required": [
                    "id", "captureID", "surfaceKind", "replyTargetSummary", "targetConfidence",
                    "relevantSnippets", "speakerHints", "targetDirection", "ignoredChromeSummary",
                    "missingContextFlags", "screenshotConfidence", "sourceIDs"
                ],
                "additionalProperties": false
            ]
        ]
    }
}

final class OpenAIOutputPlanner: OutputPlanning {
    private let config: OpenAIPlanningConfig
    private let endpoint: URL
    private let session: URLSession

    init(
        config: OpenAIPlanningConfig = .load(),
        endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        session: URLSession = .shared
    ) {
        self.config = config
        self.endpoint = endpoint
        self.session = session
    }

    func planOutput(
        capturePack: CapturePack,
        contextBrief: ContextBrief,
        knowledgeContext: KnowledgeContext
    ) async throws -> ReplyPlan {
        guard let apiKey = config.apiKey else {
            throw GenerationServiceError.missingAPIKey
        }

        let output = try await OpenAIResponsesClient(
            apiKey: apiKey,
            model: config.outputModel,
            endpoint: endpoint,
            session: session
        )
        .createResponse(
            prompt: Self.prompt(
                capturePack: capturePack,
                contextBrief: contextBrief,
                knowledgeContext: knowledgeContext
            ),
            textFormat: Self.replyPlanJSONFormat,
            maxOutputTokens: 920,
            screenshots: [],
            imageDetail: config.imageDetail,
            reasoningEffort: config.reasoningEffort,
            instructions: Self.instructions
        )

        return Self.parseReplyPlan(
            output,
            capturePack: capturePack,
            contextBrief: contextBrief
        )
    }

    static let instructions = "You are CasprFlow's build-output planner. Use the provided ContextBrief and local knowledge to produce three chips and three concise pasteable drafts. Do not ask to inspect the screenshot."

    static func prompt(
        capturePack: CapturePack,
        contextBrief: ContextBrief,
        knowledgeContext: KnowledgeContext
    ) -> String {
        """
        # Product
        CasprFlow shows three intent chips. The user can switch chips locally because every chip must have one draft.

        # Rules
        - Return exactly three chips.
        - Return exactly one concise draft per chip.
        - Default to the best chip for the current context.
        - Match the active surface.
        - Use local knowledge only when relevant.
        - Do not mention screenshots, AX, OCR, or Caspr.

        # CapturePack
        \(capturePack.debugJSON)

        # ContextBrief
        \(jsonString(contextBrief))

        # KnowledgeContext
        \(jsonString(knowledgeContext))

        Return strict JSON matching the schema.
        """
    }

    static func requestBody(
        capturePack: CapturePack,
        contextBrief: ContextBrief,
        knowledgeContext: KnowledgeContext,
        config: OpenAIPlanningConfig
    ) -> [String: Any] {
        OpenAIResponsesClient.requestBody(
            model: config.outputModel,
            prompt: prompt(
                capturePack: capturePack,
                contextBrief: contextBrief,
                knowledgeContext: knowledgeContext
            ),
            textFormat: replyPlanJSONFormat,
            maxOutputTokens: 920,
            screenshots: [],
            imageDetail: config.imageDetail,
            reasoningEffort: config.reasoningEffort,
            instructions: instructions
        )
    }

    static func parseReplyPlan(
        _ output: String,
        capturePack: CapturePack,
        contextBrief: ContextBrief
    ) -> ReplyPlan {
        guard let data = output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ReplyPlan.self, from: data),
              (try? decoded.validate()) != nil else {
            return fallbackReplyPlan(capturePack: capturePack, contextBrief: contextBrief)
        }
        return decoded
    }

    static func fallbackReplyPlan(
        capturePack: CapturePack,
        contextBrief: ContextBrief
    ) -> ReplyPlan {
        let labels = ChipFallback.labels(for: capturePack.surfaceKind)
        let chips = labels.map { label in
            ReplyPlanChip(id: slug(label), label: label)
        }
        let drafts = chips.map { chip in
            ReplyPlanDraft(
                chipID: chip.id,
                text: fallbackDraft(for: chip.label, surface: capturePack.surfaceKind)
            )
        }
        return try! ReplyPlan(
            id: "plan-\(capturePack.id)",
            contextBriefID: contextBrief.id,
            targetSummary: contextBrief.replyTargetSummary,
            targetConfidence: contextBrief.targetConfidence,
            surfaceKind: capturePack.surfaceKind,
            chips: chips,
            defaultChipID: chips[0].id,
            drafts: drafts,
            learnedLabel: nil,
            warnings: ["fallback_reply_plan"],
            fallbackReason: "Could not parse build-output response."
        )
    }

    static var replyPlanJSONFormat: [String: Any] {
        [
            "type": "json_schema",
            "name": "casprflow_reply_plan",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "id": ["type": "string"],
                    "contextBriefID": ["type": "string"],
                    "targetSummary": ["type": "string"],
                    "targetConfidence": ["type": "number"],
                    "surfaceKind": ["type": "string", "enum": surfaceKinds],
                    "chips": [
                        "type": "array",
                        "minItems": 3,
                        "maxItems": 3,
                        "items": [
                            "type": "object",
                            "properties": [
                                "id": ["type": "string"],
                                "label": ["type": "string"]
                            ],
                            "required": ["id", "label"],
                            "additionalProperties": false
                        ]
                    ],
                    "defaultChipID": ["type": "string"],
                    "drafts": [
                        "type": "array",
                        "minItems": 3,
                        "maxItems": 3,
                        "items": [
                            "type": "object",
                            "properties": [
                                "chipID": ["type": "string"],
                                "text": ["type": "string"]
                            ],
                            "required": ["chipID", "text"],
                            "additionalProperties": false
                        ]
                    ],
                    "learnedLabel": ["type": ["string", "null"]],
                    "warnings": ["type": "array", "items": ["type": "string"]],
                    "fallbackReason": ["type": ["string", "null"]]
                ],
                "required": [
                    "id", "contextBriefID", "targetSummary", "targetConfidence", "surfaceKind",
                    "chips", "defaultChipID", "drafts", "learnedLabel", "warnings", "fallbackReason"
                ],
                "additionalProperties": false
            ]
        ]
    }

    private static func fallbackDraft(for chip: String, surface: ScreenContextBundle.SurfaceKind) -> String {
        switch surface {
        case .code:
            return "Inspect the current context, make the smallest safe change for \(chip.lowercased()), and run the relevant checks."
        case .casual:
            return "Yeah, that works for me."
        case .email:
            return "Thanks for the update. I will review this and follow up shortly."
        case .chat, .browserChat:
            return "I am checking this now and will send an update shortly."
        case .docs:
            return "I will tighten this up and keep the main point clear."
        case .other:
            return "I will take a look and get back to you."
        }
    }

    private static func slug(_ label: String) -> String {
        let lower = label.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return lower.isEmpty ? UUID().uuidString : lower
    }
}

private let surfaceKinds = ["chat", "browserChat", "casual", "email", "docs", "code", "other"]
private let targetDirections = ["selected", "incoming", "outgoing", "ambiguous"]

private func jsonString<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(value),
          let string = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return string
}

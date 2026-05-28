import Foundation

public struct TieredIntentRouter: IntentRouter {
    private let tier0: DeterministicRouter
    private let tier1: LLMRouter

    public init(
        tier0: DeterministicRouter = DeterministicRouter(),
        tier1: LLMRouter = LLMRouter()
    ) {
        self.tier0 = tier0
        self.tier1 = tier1
    }

    public func route(_ text: String) async -> Intent {
        let fastIntent = tier0.routeSync(text)
        guard fastIntent.kind == .unknown else {
            NSLog("[CasprFlow] Router Tier-0 hit: %@", fastIntent.kind.rawValue)
            return fastIntent
        }

        NSLog("[CasprFlow] Router Tier-0 miss; using LLM fallback")
        return await tier1.route(text)
    }
}

public struct LLMRouter: IntentRouter {
    public static let minimumConfidence = 0.6
    public static let slotKeys = [
        "app",
        "url",
        "query",
        "engine",
        "count",
        "project",
        "dir",
        "task",
        "tool",
        "command",
        "recipient",
        "message",
        "request"
    ]

    private let client: LLMCompleting
    private let minimumConfidence: Double

    public init(
        client: LLMCompleting = LLMClient(),
        minimumConfidence: Double = Self.minimumConfidence
    ) {
        self.client = client
        self.minimumConfidence = minimumConfidence
    }

    public func route(_ text: String) async -> Intent {
        let rawText = SelectionTextNormalizer.clean(text) ?? ""
        guard !rawText.isEmpty else {
            return .unknown(rawText: rawText)
        }

        do {
            let output = try await client.complete(
                prompt: Self.classificationPrompt(for: rawText),
                instructions: Self.routerInstructions,
                textFormat: Self.intentSchema,
                maxOutputTokens: 160
            )
            let parsed = try Self.parseIntentJSON(output, rawText: rawText)
            guard parsed.confidence >= minimumConfidence else {
                NSLog(
                    "[CasprFlow] LLM router low confidence: kind=%@ confidence=%.2f",
                    parsed.kind.rawValue,
                    parsed.confidence
                )
                return .unknown(rawText: rawText)
            }
            NSLog(
                "[CasprFlow] LLM router hit: kind=%@ confidence=%.2f",
                parsed.kind.rawValue,
                parsed.confidence
            )
            return parsed
        } catch {
            NSLog("[CasprFlow] LLM router fallback failed: %@", String(describing: error))
            return .unknown(rawText: rawText)
        }
    }

    public static let routerInstructions = """
    Classify one macOS voice command into a CasprFlow intent. Output only JSON that matches the schema. Use the exact enum values. Keep slots short and literal. Use unknown if the command cannot be executed by the listed intents.
    """

    public static func classificationPrompt(for text: String) -> String {
        """
        Command: \(text)

        Intents and slots:
        - openApp: app
        - openURL: url
        - browserSearch: query, engine
        - agentSwarm: count, project, dir, task, tool
        - shell: command
        - slackReply: recipient, message
        - sqlArtifact: request
        - unknown: no slots
        """
    }

    public static var intentSchema: [String: Any] {
        let nullableStringSlot: [String: Any] = [
            "type": ["string", "null"]
        ]
        let slotProperties = slotKeys.reduce(into: [String: Any]()) { partial, key in
            partial[key] = nullableStringSlot
        }

        return [
            "type": "json_schema",
            "name": "casprflow_intent",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "properties": [
                    "kind": [
                        "type": "string",
                        "enum": IntentKind.allCases.map(\.rawValue)
                    ],
                    "slots": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": slotProperties,
                        "required": slotKeys
                    ],
                    "confidence": [
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1
                    ]
                ],
                "required": ["kind", "slots", "confidence"]
            ]
        ]
    }

    public static func parseIntentJSON(_ json: String, rawText: String) throws -> Intent {
        guard let data = json.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kindValue = object["kind"] as? String,
              let kind = IntentKind(rawValue: kindValue),
              let confidence = Self.parseConfidence(object["confidence"]) else {
            throw LLMRouterError.invalidIntentJSON
        }

        let slotsObject = object["slots"] as? [String: Any] ?? [:]
        let slots = slotsObject.reduce(into: [String: String]()) { partial, pair in
            guard let value = pair.value as? String,
                  let cleaned = SelectionTextNormalizer.clean(value) else {
                return
            }
            partial[pair.key] = cleaned
        }

        return Intent(
            kind: kind,
            slots: slots,
            confidence: confidence,
            rawText: rawText
        )
    }

    private static func parseConfidence(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) }
        return nil
    }
}

public protocol LLMCompleting: Sendable {
    func complete(
        prompt: String,
        instructions: String,
        textFormat: [String: Any]?,
        maxOutputTokens: Int
    ) async throws -> String
}

public enum LLMRouterError: Error, Equatable, Sendable {
    case invalidIntentJSON
}

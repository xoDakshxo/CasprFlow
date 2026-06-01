import Foundation

public enum IntentKind: String, CaseIterable, Equatable, Sendable {
    case openApp
    case openURL
    case shell
    case browserSearch
    case agentSwarm
    case slackReply
    case sqlArtifact
    case unknown
}

public struct Intent: Equatable, Sendable {
    public let kind: IntentKind
    public let slots: [String: String]
    public let confidence: Double
    public let rawText: String

    public init(
        kind: IntentKind,
        slots: [String: String] = [:],
        confidence: Double,
        rawText: String
    ) {
        self.kind = kind
        self.slots = slots
        self.confidence = confidence
        self.rawText = rawText
    }

    public static func unknown(rawText: String) -> Intent {
        Intent(kind: .unknown, confidence: 0, rawText: rawText)
    }
}

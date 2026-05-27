import Foundation

public protocol IntentRouter: Sendable {
    func route(_ text: String) async -> Intent
}

public struct DeterministicRouter: IntentRouter {
    private static let googleReferenceRule = RegexRule(
        #"^(?:get me|show me) (?<query>.+) from google$"#
    )
    private static let browserSearchRule = RegexRule(
        #"^(?:search|google|look up|find) (?<query>.+)$"#
    )
    private static let agentSwarmRule = RegexRule(
        #"^(?:spin up|start|launch) (?<count>\d+|a|one|two|three|four|five|six|seven|eight|nine|ten) agents?(?:.*?)\b(?:refactor|fix|do|build)\b (?<task>.+)$"#
    )
    private static let slackReplyRule = RegexRule(
        #"^(?:reply|respond|tell|message)(?: to)? (?<recipient>[a-z0-9_@.-]+)(?: (?:that|saying|with))? (?<message>.+)$"#
    )
    private static let openRule = RegexRule(
        #"^(?:open|launch|go to) (?<target>.+)$"#
    )
    private static let shellRule = RegexRule(
        #"^(?:run|execute) (?<command>.+)$"#
    )
    private static let domainRule = RegexRule(
        #"^[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+(?:[/:?#].*)?$"#
    )

    private static let spokenNumbers: [String: String] = [
        "a": "1",
        "one": "1",
        "two": "2",
        "three": "3",
        "four": "4",
        "five": "5",
        "six": "6",
        "seven": "7",
        "eight": "8",
        "nine": "9",
        "ten": "10"
    ]

    public init() {}

    public func route(_ text: String) async -> Intent {
        routeSync(text)
    }

    public func routeSync(_ text: String) -> Intent {
        let rawText = SelectionTextNormalizer.clean(text) ?? ""
        let normalizedText = Self.normalize(rawText)
        guard !normalizedText.isEmpty else {
            return .unknown(rawText: rawText)
        }

        if let match = Self.googleReferenceRule.firstMatch(in: normalizedText),
           let query = match.capture("query") {
            return Intent(
                kind: .browserSearch,
                slots: [
                    "query": query,
                    "engine": "google"
                ],
                confidence: 1,
                rawText: rawText
            )
        }

        if let match = Self.browserSearchRule.firstMatch(in: normalizedText),
           let query = match.capture("query") {
            return Intent(
                kind: .browserSearch,
                slots: ["query": query],
                confidence: 1,
                rawText: rawText
            )
        }

        if let match = Self.agentSwarmRule.firstMatch(in: normalizedText),
           let count = match.capture("count"),
           let task = match.capture("task") {
            return Intent(
                kind: .agentSwarm,
                slots: [
                    "count": Self.normalizedCount(count),
                    "task": task
                ],
                confidence: 1,
                rawText: rawText
            )
        }

        if let match = Self.slackReplyRule.firstMatch(in: normalizedText),
           let recipient = match.capture("recipient"),
           let message = match.capture("message") {
            return Intent(
                kind: .slackReply,
                slots: [
                    "recipient": recipient,
                    "message": message
                ],
                confidence: 1,
                rawText: rawText
            )
        }

        if let match = Self.openRule.firstMatch(in: normalizedText),
           let target = match.capture("target") {
            if let url = Self.normalizedURL(from: target) {
                return Intent(
                    kind: .openURL,
                    slots: ["url": url],
                    confidence: 1,
                    rawText: rawText
                )
            }

            return Intent(
                kind: .openApp,
                slots: ["app": target],
                confidence: 1,
                rawText: rawText
            )
        }

        if let match = Self.shellRule.firstMatch(in: normalizedText),
           let command = match.capture("command") {
            return Intent(
                kind: .shell,
                slots: ["command": command],
                confidence: 1,
                rawText: rawText
            )
        }

        return .unknown(rawText: rawText)
    }

    public static func normalize(_ text: String) -> String {
        let cleaned = SelectionTextNormalizer.clean(text) ?? ""
        return cleaned
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func normalizedCount(_ count: String) -> String {
        spokenNumbers[count] ?? count
    }

    private static func normalizedURL(from target: String) -> String? {
        guard !target.contains(" ") else { return nil }

        let candidate: String
        if target.contains("://") {
            candidate = target
        } else if domainRule.matchesEntireString(target) {
            candidate = "https://\(target)"
        } else {
            return nil
        }

        guard let url = URL(string: candidate),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }

        return url.absoluteString
    }
}

private struct RegexRule {
    private let expression: NSRegularExpression

    init(_ pattern: String) {
        do {
            self.expression = try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid router regex \(pattern): \(error)")
        }
    }

    func firstMatch(in text: String) -> RegexMatch? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range) else {
            return nil
        }

        return RegexMatch(text: text, checkingResult: match)
    }

    func matchesEntireString(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range) else {
            return false
        }

        return match.range.location == 0 && match.range.length == range.length
    }
}

private struct RegexMatch {
    let text: String
    let checkingResult: NSTextCheckingResult

    func capture(_ name: String) -> String? {
        let range = checkingResult.range(withName: name)
        guard range.location != NSNotFound,
              let stringRange = Range(range, in: text) else {
            return nil
        }

        return SelectionTextNormalizer.clean(String(text[stringRange]))
    }
}

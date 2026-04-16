import Foundation

public struct StubReplyGenerator: Sendable {
    private let replies: [String]

    public init() {
        replies = [
            "Thanks for sending this over. I'll take a look and get back to you shortly.",
            "Got it. I'll review this and follow up with a clear answer soon.",
            "Thanks, I see what you mean. I'll check this and reply shortly."
        ]
    }

    public func initialReply(for selectedText: String) -> String {
        guard SelectionTextNormalizer.clean(selectedText) != nil else {
            return "Highlight a message first."
        }
        return replies[0]
    }

    public func regeneratedReply(for selectedText: String, currentDraft: String, attempt: Int) -> String {
        guard SelectionTextNormalizer.clean(selectedText) != nil else {
            return "Highlight a message first."
        }

        let current = SelectionTextNormalizer.clean(currentDraft)
        let candidates = replies.filter { $0 != current }
        guard !candidates.isEmpty else { return replies[0] }
        return candidates[attempt % candidates.count]
    }
}

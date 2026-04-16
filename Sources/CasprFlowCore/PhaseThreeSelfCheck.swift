import AppKit

public enum PhaseThreeSelfCheck {
    public static func stubGeneratorReturnsOneReply() -> Bool {
        let generator = StubReplyGenerator()
        let reply = generator.initialReply(for: "Can you review this?")
        return !reply.isEmpty
            && !reply.contains("Can you review this?")
            && !reply.contains("\n\n")
    }

    public static func stubRegenerationChangesReply() -> Bool {
        let generator = StubReplyGenerator()
        let initial = generator.initialReply(for: "Can you review this?")
        let regenerated = generator.regeneratedReply(
            for: "Can you review this?",
            currentDraft: initial,
            attempt: 1
        )
        return !regenerated.isEmpty && regenerated != initial
    }

    public static func pasteServiceRejectsEmptyText() -> Bool {
        PasteService.validatedPasteText(" \n\t ") == nil
    }

    public static func pasteServiceKeepsUserTextUntrimmed() -> Bool {
        PasteService.validatedPasteText("  keep spacing  ") == "  keep spacing  "
    }

    @MainActor
    public static func canCreatePhaseThreeCapsule() -> Bool {
        _ = NSApplication.shared
        _ = ReplyCapsuleController()
        return true
    }
}

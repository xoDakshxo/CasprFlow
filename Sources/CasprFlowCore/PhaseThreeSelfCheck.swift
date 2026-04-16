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

    public static func promptContextWorksWithoutSelection() -> Bool {
        let prompt = ScreenContext.makePromptContext(
            captureResult: .empty,
            appName: "Notes",
            windowTitle: "Project notes",
            focusedElementRole: "AXTextArea",
            fullElementValue: "Can you send the updated timeline today?\n\n",
            surroundingText: nil,
            visibleElements: []
        )

        return prompt.hasUsableContext
            && prompt.captureMode == .axOnly
            && prompt.text.contains("Can you send the updated timeline today?")
            && prompt.confidence > 0.5
    }

    public static func promptContextDropsChrome() -> Bool {
        let prompt = ScreenContext.makePromptContext(
            captureResult: .empty,
            appName: "Browser",
            windowTitle: "Chat",
            focusedElementRole: "AXTextField",
            fullElementValue: nil,
            surroundingText: nil,
            visibleElements: [
                ScreenContext.VisibleElement(role: "AXButton", label: "Send", value: nil, identifier: nil, depth: 1),
                ScreenContext.VisibleElement(role: "AXStaticText", label: "Can you review this today?", value: nil, identifier: nil, depth: 2)
            ]
        )

        return prompt.text.contains("Can you review this today?")
            && !prompt.text.contains("Send")
            && prompt.droppedCandidateCount > 0
    }

    @MainActor
    public static func canCreatePhaseThreeCapsule() -> Bool {
        _ = NSApplication.shared
        _ = ReplyCapsuleController()
        return true
    }
}

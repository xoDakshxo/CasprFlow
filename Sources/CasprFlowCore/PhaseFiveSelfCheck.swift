import Foundation

public enum PhaseFiveSelfCheck {
    public static func chipPromptIncludesBundlePrompt() -> Bool {
        let bundle = sampleBundle(kind: .chat, appName: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let prompt = GenerationPromptBuilder.chipPrompt(for: bundle, userProfile: sampleUser)
        let ax = GenerationPromptBuilder.axContext(for: bundle)
        return prompt.contains("screenshot intent reader")
            && prompt.contains("Return exactly")
            && prompt.contains("The person using Caspr is Daksh")
            && prompt.contains("latest visible incoming message")
            && ax.contains("LinkedList access handling")
    }

    public static func malformedChipJSONFallsBack() -> Bool {
        let chips = OpenAIGenerationService.parseAIChips(
            #"{"chips":["This chip is much too long to pick quickly","Ask for more context","say yes"]}"#,
            fallbackKind: .chat
        )
        return chips.map(\.label) == ["This chip is", "Ask for more", "say yes"]
    }

    public static func slackFallbackUsesChatChips() -> Bool {
        let chips = ChipFallback.chips(for: .chat)
        return chips.map(\.label) == ["Take it", "Push timing", "Ask context"]
    }

    public static func expansionPromptIncludesChipAndEdit() -> Bool {
        let bundle = sampleBundle(kind: .code, appName: "Cursor", bundleId: "com.todesktop.230313mzl4w4u92")
        let prompt = GenerationPromptBuilder.expansionPrompt(
            chip: Chip(label: "Implement"),
            bundle: bundle,
            edit: "make it safer",
            previousDraft: "Add the access handling.",
            userProfile: sampleUser
        )
        return prompt.contains("Chosen intent: Implement")
            && prompt.contains("make it safer")
            && prompt.contains("Previous generated draft")
            && prompt.contains("You are writing as Daksh")
            && prompt.contains("Write only the final pasteable text")
    }

    public static func screenshotFallbackAttachesOnlyWhenConfidenceIsLow() -> Bool {
        let low = ScreenContextBundle.assemble(
            appName: "Browser",
            bundleId: "com.apple.Safari",
            windowTitle: nil,
            focusedRole: nil,
            focusedSubrole: nil,
            focusedValue: nil,
            selection: nil,
            rawAXCandidates: ["Send"],
            ocrCandidates: [],
            screenshots: [],
            droppedCount: 0
        )
        let high = sampleBundle(kind: .chat, appName: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let screenshot = ScreenshotAttachment(
            metadata: ScreenshotMetadata(source: "focusedInteractionRegion", windowID: 7, width: 800, height: 600),
            data: Data([1, 2, 3]),
            mimeType: "image/jpeg"
        )

        return OpenAIGenerationService.screenshotsForRequest(bundle: low, screenshots: [screenshot]).count == 1
            && OpenAIGenerationService.screenshotsForRequest(bundle: high, screenshots: [screenshot]).isEmpty
    }

    public static func openAIRequestUsesResponsesImageContent() -> Bool {
        let screenshot = ScreenshotAttachment(
            metadata: ScreenshotMetadata(source: "focusedInteractionRegion", windowID: 7, width: 800, height: 600),
            data: Data([1, 2, 3]),
            mimeType: "image/jpeg"
        )
        let content = OpenAIResponsesClient.inputContent(prompt: "hello", screenshots: [screenshot])
        guard content.count == 2,
              content[0]["type"] as? String == "input_text",
              content[1]["type"] as? String == "input_image",
              content[1]["detail"] as? String == "high",
              let imageURL = content[1]["image_url"] as? String else {
            return false
        }
        return imageURL.hasPrefix("data:image/jpeg;base64,")
    }

    public static func chipPromptUsesAXButNotOCR() -> Bool {
        let bundle = ScreenContextBundle.assemble(
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            windowTitle: "general",
            focusedRole: "AXTextArea",
            focusedSubrole: nil,
            focusedValue: nil,
            selection: "Can you add LinkedList access handling today?",
            rawAXCandidates: ["Can you add LinkedList access handling today?"],
            ocrCandidates: [
                OCRTextCandidate(
                    text: "OCR SHOULD NOT BE IN PROMPT",
                    confidence: 0.9,
                    boundingBox: NormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.1),
                    source: "focusedInteractionRegion"
                )
            ],
            screenshots: [],
            droppedCount: 0
        )
        let prompt = GenerationPromptBuilder.chipPrompt(for: bundle, userProfile: sampleUser)
        let ax = GenerationPromptBuilder.axContext(for: bundle)
        return prompt.contains("no OCR transcript")
            && ax.contains("LinkedList access handling")
            && !prompt.contains("OCR SHOULD NOT BE IN PROMPT")
    }

    public static func chipParserExtractsWrappedJSON() -> Bool {
        let chips = OpenAIGenerationService.parseAIChips(
            """
            Sure:
            {"chips":["Take it","Push timing","Ask context"]}
            """,
            fallbackKind: .chat
        )
        return chips.map(\.label) == ["Take it", "Push timing", "Ask context"]
    }

    @MainActor
    public static func mockServiceRoundTrips() async -> Bool {
        let service = MockGenerationService()
        let bundle = sampleBundle(kind: .chat, appName: "Slack", bundleId: "com.tinyspeck.slackmacgap")
        let chips = (try? await service.chips(for: bundle, screenshots: [])) ?? []
        let expansion = try? await service.expand(
            chip: chips.first ?? Chip(label: "Take it"),
            bundle: bundle,
            edit: nil,
            previousDraft: nil,
            screenshots: []
        )
        return chips.count == 3
            && expansion == "Mock expansion: \(chips.first?.label ?? "")"
    }

    private static func sampleBundle(
        kind: ScreenContextBundle.SurfaceKind,
        appName: String,
        bundleId: String
    ) -> ScreenContextBundle {
        ScreenContextBundle.assemble(
            appName: appName,
            bundleId: bundleId,
            windowTitle: "general",
            focusedRole: kind == .code ? "AXTextArea" : "AXTextField",
            focusedSubrole: nil,
            focusedValue: nil,
            selection: nil,
            rawAXCandidates: ["Can you add LinkedList access handling to onboarding today?"],
            ocrCandidates: [],
            screenshots: [],
            droppedCount: 0
        )
    }

    private static var sampleUser: UserProfile {
        UserProfile(
            name: "Daksh",
            style: "direct and natural",
            workContext: "building CasprFlow"
        )
    }
}

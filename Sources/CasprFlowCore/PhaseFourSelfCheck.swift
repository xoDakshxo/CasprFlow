import Foundation

public enum PhaseFourSelfCheck {
    public static func surfaceClassifierDetectsSlack() -> Bool {
        SurfaceClassifier.classify(
            bundleId: "com.tinyspeck.slackmacgap",
            appName: "Slack",
            windowTitle: "general",
            focusedRole: "AXTextArea",
            focusedSubrole: nil
        ) == .chat
    }

    public static func surfaceClassifierDetectsCode() -> Bool {
        let xcode = SurfaceClassifier.classify(
            bundleId: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: nil,
            focusedRole: nil,
            focusedSubrole: nil
        )
        let cursor = SurfaceClassifier.classify(
            bundleId: "com.todesktop.230313mzl4w4u92",
            appName: "Cursor",
            windowTitle: nil,
            focusedRole: nil,
            focusedSubrole: nil
        )
        return xcode == .code && cursor == .code
    }

    public static func surfaceClassifierDetectsCasual() -> Bool {
        SurfaceClassifier.classify(
            bundleId: "com.apple.MobileSMS",
            appName: "Messages",
            windowTitle: nil,
            focusedRole: nil,
            focusedSubrole: nil
        ) == .casual
    }

    public static func surfaceClassifierFallsBackToOther() -> Bool {
        SurfaceClassifier.classify(
            bundleId: "com.example.unknown",
            appName: "Unknown",
            windowTitle: nil,
            focusedRole: nil,
            focusedSubrole: nil
        ) == .other
    }

    public static func ocrGroupingMergesAdjacentLines() -> Bool {
        let lines = [
            OCRTextCandidate(
                text: "Hey, can you take a look at the onboarding flow",
                confidence: 0.92,
                boundingBox: NormalizedRect(x: 0.10, y: 0.62, width: 0.60, height: 0.030),
                source: "focusedInteractionRegion"
            ),
            OCRTextCandidate(
                text: "and add LinkedList access handling today?",
                confidence: 0.91,
                boundingBox: NormalizedRect(x: 0.10, y: 0.585, width: 0.55, height: 0.030),
                source: "focusedInteractionRegion"
            ),
            OCRTextCandidate(
                text: "Send",
                confidence: 0.88,
                boundingBox: NormalizedRect(x: 0.85, y: 0.10, width: 0.05, height: 0.020),
                source: "focusedInteractionRegion"
            )
        ]
        let blocks = OCRBlockGrouper.group(lines)
        guard let first = blocks.first else { return false }
        return blocks.count == 2
            && first.text.contains("onboarding flow")
            && first.text.contains("LinkedList")
    }

    public static func bundleIncludesGroupedRecentBlock() -> Bool {
        let bundle = ScreenContextBundle.assemble(
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            windowTitle: "general",
            focusedRole: "AXTextArea",
            focusedSubrole: nil,
            focusedValue: nil,
            selection: nil,
            rawAXCandidates: ["Send", "general"],
            ocrCandidates: [
                OCRTextCandidate(
                    text: "Can you add LinkedList access handling to onboarding today?",
                    confidence: 0.93,
                    boundingBox: NormalizedRect(x: 0.10, y: 0.50, width: 0.60, height: 0.030),
                    source: "focusedInteractionRegion"
                )
            ],
            screenshots: [],
            droppedCount: 0
        )
        return bundle.surface.kind == .chat
            && bundle.recent.contains(where: { $0.text.contains("LinkedList access handling") })
            && bundle.prompt.contains("Surface: chat")
            && bundle.prompt.contains("LinkedList access handling")
    }

    public static func bundleExcludesChromeAmbient() -> Bool {
        let bundle = ScreenContextBundle.assemble(
            appName: "Browser",
            bundleId: "com.apple.Safari",
            windowTitle: "Chat",
            focusedRole: "AXTextField",
            focusedSubrole: nil,
            focusedValue: nil,
            selection: nil,
            rawAXCandidates: ["Send", "Submit", "Can you review this today?"],
            ocrCandidates: [],
            screenshots: [],
            droppedCount: 0
        )
        return !bundle.prompt.contains("Send")
            && !bundle.prompt.contains("Submit")
            && bundle.prompt.contains("Can you review this today?")
    }

    public static func confidenceLadderSelectionWins() -> Bool {
        let bundle = ScreenContextBundle.assemble(
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            windowTitle: "general",
            focusedRole: "AXTextArea",
            focusedSubrole: nil,
            focusedValue: nil,
            selection: "Highlighted reply target",
            rawAXCandidates: [],
            ocrCandidates: [],
            screenshots: [],
            droppedCount: 0
        )
        return bundle.confidence == 1.00 && bundle.needsScreenshotFallback == false
    }

    public static func confidenceLadderFocusedFieldPlusRecent() -> Bool {
        let bundle = ScreenContextBundle.assemble(
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            windowTitle: "general",
            focusedRole: "AXTextArea",
            focusedSubrole: nil,
            focusedValue: String(repeating: "x", count: 60),
            selection: nil,
            rawAXCandidates: ["Can you take a look at the onboarding flow today please"],
            ocrCandidates: [],
            screenshots: [],
            droppedCount: 0
        )
        return bundle.confidence == 0.85 && bundle.needsScreenshotFallback == false
    }

    public static func confidenceLadderInputFocusedPlusRecent() -> Bool {
        let bundle = ScreenContextBundle.assemble(
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            windowTitle: "general",
            focusedRole: "AXTextArea",
            focusedSubrole: nil,
            focusedValue: nil,
            selection: nil,
            rawAXCandidates: ["Can you take a look at the onboarding flow today please"],
            ocrCandidates: [],
            screenshots: [],
            droppedCount: 0
        )
        return bundle.confidence == 0.70 && bundle.needsScreenshotFallback == false
    }

    public static func confidenceLadderAmbientOnlyTriggersFallback() -> Bool {
        let bundle = ScreenContextBundle.assemble(
            appName: "Browser",
            bundleId: "com.apple.Safari",
            windowTitle: nil,
            focusedRole: nil,
            focusedSubrole: nil,
            focusedValue: nil,
            selection: nil,
            rawAXCandidates: ["Send", "Submit"],
            ocrCandidates: [],
            screenshots: [],
            droppedCount: 0
        )
        return bundle.confidence == 0.30 && bundle.needsScreenshotFallback == true
    }

    public static func confidenceLadderEmptyTriggersFallback() -> Bool {
        let bundle = ScreenContextBundle.assemble(
            appName: nil,
            bundleId: nil,
            windowTitle: nil,
            focusedRole: nil,
            focusedSubrole: nil,
            focusedValue: nil,
            selection: nil,
            rawAXCandidates: [],
            ocrCandidates: [],
            screenshots: [],
            droppedCount: 0
        )
        return bundle.confidence == 0.00 && bundle.needsScreenshotFallback == true
    }

    public static func bundleRoundtripsAsJSON() -> Bool {
        let bundle = ScreenContextBundle.assemble(
            appName: "Notes",
            bundleId: "com.apple.Notes",
            windowTitle: "Project notes",
            focusedRole: "AXTextArea",
            focusedSubrole: nil,
            focusedValue: "Draft",
            selection: nil,
            rawAXCandidates: ["Some visible AX text that is long enough to count."],
            ocrCandidates: [],
            screenshots: [],
            droppedCount: 0
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(bundle),
              let decoded = try? decoder.decode(ScreenContextBundle.self, from: data) else {
            return false
        }
        return decoded == bundle
    }
}

import Foundation

public enum KnowledgeFastRepliesPhaseOneSelfCheck {
    public static func highConfidenceSelectedTextSkipsScreenshot() -> Bool {
        let bundle = sampleBundle(selection: "Can you send the update?", confidenceSource: .selection)
        let pack = CapturePackBuilder.build(
            from: bundle,
            screenshots: [sampleScreenshot()],
            id: "capture-1",
            capturedAt: sampleDate
        )

        return pack.screenshot == nil
            && pack.screenshotDecision.action == .skipped
            && pack.selection == "Can you send the update?"
    }

    public static func lowConfidenceContextAttachesOneScreenshot() -> Bool {
        let bundle = sampleBundle(selection: nil, confidenceSource: .ambientOnly)
        let pack = CapturePackBuilder.build(
            from: bundle,
            screenshots: [sampleScreenshot(), sampleScreenshot(source: "visibleWindowRegion")],
            id: "capture-1",
            capturedAt: sampleDate
        )

        return pack.screenshot?.metadata.source == "focusedInteractionRegion"
            && pack.screenshot?.data?.count == 3
            && pack.screenshotDecision.action == .attached
    }

    public static func redactionRemovesObviousSecrets() -> Bool {
        let text = "token=abcd1234SECRET password: hunter2 Bearer abcdefghijklmnopqrstuvwxyz123456 sk-1234567890abcdefghijkl"
        let redacted = CapturePackBuilder.redact(text)
        return redacted.contains("[redacted:secret]")
            && redacted.contains("Bearer [redacted:token]")
            && redacted.contains("[redacted:api_key]")
            && !redacted.contains("hunter2")
            && !redacted.contains("sk-1234567890abcdefghijkl")
    }

    public static func chromePruningDropsButtons() -> Bool {
        CapturePackBuilder.isLikelyChrome("Send")
            && CapturePackBuilder.isLikelyChrome("10:42 PM")
            && CapturePackBuilder.isLikelyChrome("#general")
            && !CapturePackBuilder.isLikelyChrome("Can you send the retry update?")
    }

    public static func debugJSONStaysCompact() -> Bool {
        let bundle = sampleBundle(selection: nil, confidenceSource: .ambientOnly)
        let pack = CapturePackBuilder.build(
            from: bundle,
            screenshots: [sampleScreenshot(data: Data(repeating: 7, count: 4_000))],
            id: "capture-1",
            capturedAt: sampleDate
        )
        let debugJSON = pack.debugJSON
        return debugJSON.count < 4_000
            && debugJSON.contains(#""attachedBytes" : 4000"#)
            && !debugJSON.contains(Data(repeating: 7, count: 24).base64EncodedString())
    }

    private enum ConfidenceSource {
        case selection
        case ambientOnly
    }

    private static func sampleBundle(
        selection: String?,
        confidenceSource: ConfidenceSource
    ) -> ScreenContextBundle {
        let rawAX: [String]
        let focusedRole: String?
        switch confidenceSource {
        case .selection:
            rawAX = ["Can you send the update?", "Send", "10:42 PM"]
            focusedRole = "AXTextArea"
        case .ambientOnly:
            rawAX = ["Send", "Search", "general"]
            focusedRole = nil
        }

        return ScreenContextBundle.assemble(
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            windowTitle: "general",
            focusedRole: focusedRole,
            focusedSubrole: nil,
            focusedValue: nil,
            selection: selection,
            rawAXCandidates: rawAX,
            ocrCandidates: [],
            screenshots: [
                ScreenshotMetadata(source: "focusedInteractionRegion", windowID: 7, width: 640, height: 420),
                ScreenshotMetadata(source: "visibleWindowRegion", windowID: 7, width: 1200, height: 900)
            ],
            droppedCount: 0
        )
    }

    private static func sampleScreenshot(
        source: String = "focusedInteractionRegion",
        data: Data = Data([1, 2, 3])
    ) -> ScreenshotAttachment {
        ScreenshotAttachment(
            metadata: ScreenshotMetadata(source: source, windowID: 7, width: 640, height: 420),
            data: data,
            mimeType: "image/jpeg"
        )
    }

    private static var sampleDate: Date {
        Date(timeIntervalSince1970: 1_771_840_800)
    }
}

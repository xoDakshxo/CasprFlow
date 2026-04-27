import Foundation

enum CapturePackBuilder {
    static let maxRecentBlocks = 8
    static let maxRecentTextLength = 520
    static let maxAmbient = 6
    static let maxAmbientTextLength = 160
    static let maxVisibleAXCandidates = 14
    static let maxVisibleAXTextLength = 260
    static let maxFocusedValueLength = 360
    static let maxSelectionLength = 1200

    static func build(
        from bundle: ScreenContextBundle,
        screenshots: [ScreenshotAttachment],
        id: String = UUID().uuidString,
        capturedAt: Date = Date()
    ) -> CapturePack {
        let metadata = bundle.debug.screenshots.map {
            ScreenshotMetadata(
                source: $0.source,
                windowID: $0.windowID,
                width: $0.width,
                height: $0.height
            )
        }

        let attachment = screenshotAttachment(
            for: bundle,
            screenshots: screenshots
        )

        return CapturePack(
            id: id,
            capturedAt: capturedAt,
            appName: clean(bundle.surface.appName, limit: 80),
            bundleId: clean(bundle.surface.bundleId, limit: 120),
            windowTitle: clean(bundle.surface.windowTitle, limit: 180),
            surfaceKind: bundle.surface.kind,
            focusedField: focusedField(from: bundle.focused),
            selection: clean(bundle.selection, limit: maxSelectionLength),
            recent: recentBlocks(from: bundle.recent),
            ambient: cappedStrings(bundle.ambient, limit: maxAmbient, textLimit: maxAmbientTextLength),
            visibleAXCandidates: visibleAXCandidates(from: bundle.debug.rawAXCandidates),
            screenshotMetadata: metadata,
            screenshot: attachment.screenshot,
            confidence: bundle.confidence,
            screenshotDecision: attachment.decision
        )
    }

    static func redact(_ value: String) -> String {
        var out = value
        let replacements: [(String, String)] = [
            (#"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{16,}"#, "Bearer [redacted:token]"),
            (#"(?i)\b(password|passwd|token|secret|api[_-]?key)\s*[:=]\s*["']?[^"'\s,;]{4,}"#, "$1=[redacted:secret]"),
            (#"\bsk-[A-Za-z0-9_-]{16,}"#, "[redacted:api_key]"),
            (#"\b[A-Za-z0-9_-]{32,}\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\b"#, "[redacted:token]")
        ]

        for (pattern, replacement) in replacements {
            out = out.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression]
            )
        }
        return out
    }

    static func isLikelyChrome(_ value: String) -> Bool {
        let trimmed = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let lower = trimmed.lowercased()
        let exactChrome: Set<String> = [
            "send", "submit", "cancel", "close", "minimize", "search", "new message",
            "reply", "edit", "copy", "paste", "share", "back", "next", "done", "today",
            "thread", "threads", "mentions", "drafts", "files", "later", "more", "home",
            "apps", "general"
        ]
        if exactChrome.contains(lower) { return true }
        if lower.hasPrefix("q search:") || lower.hasPrefix("search:") { return true }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return true }
        if trimmed.count <= 3, !trimmed.contains("?"), !trimmed.contains("!") { return true }
        if trimmed.hasPrefix("•"), trimmed.contains("...") { return true }
        if trimmed.range(of: #"(?i)\((channel|direct message|workspace)\)\s+-\s+.+\s+-\s+slack$"#, options: .regularExpression) != nil {
            return true
        }
        if trimmed.range(of: #"^\d{1,2}:\d{2}\s?(am|pm)?$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        if trimmed.range(of: #"^[#@][a-z0-9._-]{2,24}$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        return false
    }

    private static func focusedField(
        from focused: ScreenContextBundle.FocusedField?
    ) -> CapturePack.FocusedFieldSummary? {
        guard let focused else { return nil }
        return CapturePack.FocusedFieldSummary(
            role: clean(focused.role, limit: 80),
            subrole: clean(focused.subrole, limit: 80),
            valueSummary: clean(focused.value, limit: maxFocusedValueLength),
            fieldKind: focused.fieldKind
        )
    }

    private static func recentBlocks(
        from blocks: [ScreenContextBundle.MessageBlock]
    ) -> [ScreenContextBundle.MessageBlock] {
        Array(blocks.compactMap { block in
            guard let text = clean(block.text, limit: maxRecentTextLength),
                  !isLikelyChrome(text) else {
                return nil
            }
            return ScreenContextBundle.MessageBlock(
                text: text,
                source: block.source,
                confidence: block.confidence,
                boundingBox: block.boundingBox
            )
        }.prefix(maxRecentBlocks))
    }

    private static func visibleAXCandidates(from values: [String]) -> [String] {
        cappedStrings(values, limit: maxVisibleAXCandidates, textLimit: maxVisibleAXTextLength)
    }

    private static func cappedStrings(
        _ values: [String],
        limit: Int,
        textLimit: Int
    ) -> [String] {
        var out: [String] = []
        var seen = Set<String>()

        for value in values {
            guard let cleaned = clean(value, limit: textLimit),
                  !isLikelyChrome(cleaned) else {
                continue
            }
            let key = cleaned
                .lowercased()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            guard seen.insert(key).inserted else { continue }
            out.append(cleaned)
            if out.count >= limit { break }
        }
        return out
    }

    private static func screenshotAttachment(
        for bundle: ScreenContextBundle,
        screenshots: [ScreenshotAttachment]
    ) -> (screenshot: CapturePack.Screenshot?, decision: CapturePack.ScreenshotDecision) {
        if bundle.confidence >= ScreenContextBundle.textOnlyConfidenceThreshold {
            return (
                nil,
                CapturePack.ScreenshotDecision(
                    action: .skipped,
                    reason: "text confidence \(formatted(bundle.confidence)) is high enough"
                )
            )
        }

        guard let screenshot = screenshots.first else {
            return (
                nil,
                CapturePack.ScreenshotDecision(
                    action: .unavailable,
                    reason: "text confidence \(formatted(bundle.confidence)) is low, but no screenshot attachment is available"
                )
            )
        }

        return (
            CapturePack.Screenshot(
                metadata: screenshot.metadata,
                data: screenshot.data,
                mimeType: screenshot.mimeType
            ),
            CapturePack.ScreenshotDecision(
                action: .attached,
                reason: "text confidence \(formatted(bundle.confidence)) needs screenshot context"
            )
        )
    }

    private static func clean(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let cleaned = redact(value)
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(limit))
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

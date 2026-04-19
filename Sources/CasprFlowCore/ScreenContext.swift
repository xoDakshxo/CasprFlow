import Foundation

/// Everything we can scrape from the screen at hotkey time.
/// Structured so an AI consumer can reconstruct what the user sees and infer intent.
struct ScreenContext: Equatable {
    enum CaptureMode: String, Equatable {
        case selectedText
        case axPlusOCR
        case axOnly
        case ocrOnly
        case insufficientContext
        case permissionRequired
    }

    struct PromptContext: Equatable {
        let text: String
        let confidence: Double
        let captureMode: CaptureMode
        let candidateCount: Int
        let droppedCandidateCount: Int

        var hasUsableContext: Bool {
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        static let empty = PromptContext(
            text: "",
            confidence: 0,
            captureMode: .insufficientContext,
            candidateCount: 0,
            droppedCandidateCount: 0
        )
    }

    // MARK: - Text around the cursor

    struct SurroundingText: Equatable {
        let before: String   // Up to maxLength chars before selection
        let selected: String // The highlighted text
        let after: String    // Up to maxLength chars after selection

        static let maxLength = 500
    }

    // MARK: - Visible UI element scraped from AX tree

    struct VisibleElement: Equatable {
        let role: String          // AXRole (e.g. "AXStaticText", "AXButton")
        let label: String?        // AXTitle or AXDescription — human-readable label
        let value: String?        // AXValue — text content (truncated)
        let identifier: String?   // AXIdentifier
        let depth: Int            // Nesting depth from window root

        static let maxValueLength = 300
    }

    // MARK: - Local OCR

    // OCR / screenshot value types live at the top of the module
    // (see ScreenContextBundle.swift) so the public bundle can use them.

    // MARK: - Window info

    struct WindowInfo: Equatable {
        let title: String
        let isFocused: Bool
    }

    // MARK: - Core capture

    let captureResult: SelectionCaptureResult
    let promptContext: PromptContext

    // MARK: - Application

    let appName: String?
    let bundleIdentifier: String?
    let processIdentifier: pid_t?

    // MARK: - Window

    let windowTitle: String?
    let allWindows: [WindowInfo]

    // MARK: - Focused element

    let focusedElementRole: String?
    let focusedElementSubrole: String?
    let elementDescription: String?
    let documentURL: String?
    let elementIdentifier: String?
    let fullElementValue: String?  // Full text content of focused element (up to 2000 chars)

    // MARK: - Surrounding text

    let surroundingText: SurroundingText?

    // MARK: - Visible UI tree

    /// Flattened list of visible elements in the focused window (up to maxVisibleElements).
    let visibleElements: [VisibleElement]

    // MARK: - OCR

    /// OCR text recognized locally from interaction-targeted screenshots.
    let ocrTextCandidates: [OCRTextCandidate]
    let screenshotMetadata: [ScreenshotMetadata]
    /// Compressed screenshot data retained only for Phase 5 low-confidence model fallback.
    let screenshotAttachments: [ScreenshotAttachment]

    /// Canonical structured bundle. Built from the fields above. Phase 4+ consumers
    /// should read `bundle` instead of poking individual AX/OCR collections.
    public var bundle: ScreenContextBundle {
        let ax = collectAXCandidates()
        return ScreenContextBundle.assemble(
            appName: appName,
            bundleId: bundleIdentifier,
            windowTitle: windowTitle,
            focusedRole: focusedElementRole,
            focusedSubrole: focusedElementSubrole,
            focusedValue: fullElementValue,
            selection: selectedText,
            rawAXCandidates: ax,
            ocrCandidates: ocrTextCandidates,
            screenshots: screenshotMetadata,
            droppedCount: promptContext.droppedCandidateCount
        )
    }

    private func collectAXCandidates() -> [String] {
        var out: [String] = []
        if let surroundingText {
            if !surroundingText.before.isEmpty { out.append(surroundingText.before) }
            if !surroundingText.after.isEmpty { out.append(surroundingText.after) }
        }
        for el in visibleElements {
            if let label = el.label, !label.isEmpty { out.append(label) }
            if let value = el.value, !value.isEmpty { out.append(value) }
        }
        return out
    }

    // MARK: - Limits

    static let maxWindowTitleLength = 200
    static let maxFullValueLength = 2000
    static let maxVisibleElements = 80
    static let maxTreeDepth = 6
    static let maxPromptContextLength = 3200

    // MARK: - Convenience

    var selectedText: String? {
        if case .selected(let text) = captureResult {
            return text
        }
        return nil
    }

    static func makePromptContext(
        captureResult: SelectionCaptureResult,
        appName: String?,
        windowTitle: String?,
        focusedElementRole: String?,
        fullElementValue: String?,
        surroundingText: SurroundingText?,
        visibleElements: [VisibleElement],
        ocrTextCandidates: [OCRTextCandidate]
    ) -> PromptContext {
        var candidates: [String] = []
        var dropped = 0
        var mode: CaptureMode = .axOnly
        var hasAXCandidate = false
        var hasOCRCandidate = false

        if case .permissionRequired = captureResult {
            return PromptContext(
                text: "",
                confidence: 0,
                captureMode: .permissionRequired,
                candidateCount: 0,
                droppedCandidateCount: 0
            )
        }

        if case .selected(let selected) = captureResult,
           let cleaned = SelectionTextNormalizer.clean(selected) {
            mode = .selectedText
            candidates.append("Selected text:\n\(cleaned)")
            hasAXCandidate = true
        } else if case .empty = captureResult {
            mode = .axOnly
        }

        if let surroundingText {
            let before = Self.cleanCandidate(surroundingText.before)
            let after = Self.cleanCandidate(surroundingText.after)
            if let before, !before.isEmpty {
                candidates.append("Text before focus:\n\(before)")
                hasAXCandidate = true
            }
            if let after, !after.isEmpty {
                candidates.append("Text after focus:\n\(after)")
                hasAXCandidate = true
            }
        }

        if let fullElementValue = cleanCandidate(fullElementValue) {
            candidates.append("Focused field text:\n\(fullElementValue)")
            hasAXCandidate = true
        }

        for element in visibleElements {
            guard !Self.isChromeRole(element.role) else {
                dropped += 1
                continue
            }

            let text = element.label ?? element.value
            guard let cleaned = cleanCandidate(text) else {
                dropped += 1
                continue
            }

            candidates.append(cleaned)
            hasAXCandidate = true
        }

        let ocrLines = ocrTextCandidates.compactMap { candidate -> String? in
            cleanCandidate(candidate.text)
        }
        let dedupedOCRLines = dedupe(ocrLines)
        dropped += max(0, ocrLines.count - dedupedOCRLines.count)

        if !dedupedOCRLines.isEmpty {
            hasOCRCandidate = true
            candidates.append("OCR text:\n" + dedupedOCRLines.prefix(16).joined(separator: "\n"))
        }

        let deduped = dedupe(candidates)
        dropped += max(0, candidates.count - deduped.count)

        if case .selected = captureResult {
            mode = .selectedText
        } else if hasAXCandidate && hasOCRCandidate {
            mode = .axPlusOCR
        } else if hasOCRCandidate {
            mode = .ocrOnly
        } else {
            mode = .axOnly
        }

        var promptParts: [String] = []
        if let appName {
            promptParts.append("App: \(appName)")
        }
        if let windowTitle {
            promptParts.append("Window: \(windowTitle)")
        }
        if let focusedElementRole {
            promptParts.append("Focused element: \(focusedElementRole)")
        }

        if !deduped.isEmpty {
            promptParts.append("Visible context:\n" + deduped.prefix(12).joined(separator: "\n"))
        }

        let promptText = String(promptParts.joined(separator: "\n\n").prefix(maxPromptContextLength))
        let confidence = confidenceScore(
            captureResult: captureResult,
            appName: appName,
            windowTitle: windowTitle,
            focusedElementRole: focusedElementRole,
            candidateCount: deduped.count,
            ocrCandidateCount: ocrTextCandidates.count,
            hasAXCandidate: hasAXCandidate,
            promptText: promptText
        )

        if promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mode = .insufficientContext
        }

        return PromptContext(
            text: promptText,
            confidence: confidence,
            captureMode: mode,
            candidateCount: deduped.count,
            droppedCandidateCount: dropped
        )
    }

    private static func confidenceScore(
        captureResult: SelectionCaptureResult,
        appName: String?,
        windowTitle: String?,
        focusedElementRole: String?,
        candidateCount: Int,
        ocrCandidateCount: Int,
        hasAXCandidate: Bool,
        promptText: String
    ) -> Double {
        guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return 0
        }

        var score = 0.20
        if appName != nil { score += 0.10 }
        if windowTitle != nil { score += 0.10 }
        if focusedElementRole != nil { score += 0.10 }
        if case .selected = captureResult { score += 0.20 }
        if candidateCount >= 1 { score += 0.15 }
        if candidateCount >= 3 { score += 0.10 }
        if ocrCandidateCount >= 1 { score += 0.10 }
        if hasAXCandidate && ocrCandidateCount >= 1 { score += 0.05 }
        if promptText.count > 120 { score += 0.10 }

        let lowercased = promptText.lowercased()
        if lowercased.contains("?") || lowercased.contains(":") {
            score += 0.05
        }

        return min(score, 0.95)
    }

    private static func dedupe(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let key = value
                .lowercased()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(value)
        }

        return result
    }

    private static func cleanCandidate(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }
        return String(trimmed.prefix(500))
    }

    private static func isChromeRole(_ role: String) -> Bool {
        switch role {
        case "AXButton", "AXMenuButton", "AXMenuItem", "AXToolbar", "AXTabGroup",
             "AXScrollBar", "AXSlider", "AXCheckBox", "AXRadioButton":
            return true
        default:
            return false
        }
    }
}

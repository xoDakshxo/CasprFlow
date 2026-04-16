import Foundation

/// Everything we can scrape from the screen at hotkey time.
/// Structured so an AI consumer can reconstruct what the user sees and infer intent.
struct ScreenContext: Equatable {
    enum CaptureMode: String, Equatable {
        case selectedText
        case axOnly
        case clipboardSelection
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

    /// Produce a structured text dump suitable for feeding to an LLM.
    var aiDescription: String {
        var parts: [String] = []

        if let app = appName {
            parts.append("App: \(app)" + (bundleIdentifier.map { " (\($0))" } ?? ""))
        }
        if let processIdentifier {
            parts.append("PID: \(processIdentifier)")
        }
        if let title = windowTitle {
            parts.append("Window: \(title)")
        }
        if let url = documentURL {
            parts.append("Document: \(url)")
        }
        if allWindows.count > 1 {
            let titles = allWindows.map { ($0.isFocused ? "* " : "  ") + $0.title }
            parts.append("Open windows:\n" + titles.joined(separator: "\n"))
        }
        if let role = focusedElementRole {
            parts.append("Focused element: \(role)" + (focusedElementSubrole.map { "/\($0)" } ?? ""))
        }
        if let desc = elementDescription {
            parts.append("Element description: \(desc)")
        }
        if let selected = selectedText {
            parts.append("Selected text: \(selected)")
        }
        if promptContext.hasUsableContext {
            parts.append("Prompt context (\(promptContext.captureMode.rawValue), confidence \(String(format: "%.2f", promptContext.confidence))):\n\(promptContext.text)")
        }
        if let surrounding = surroundingText {
            if !surrounding.before.isEmpty {
                parts.append("Text before selection: \(surrounding.before)")
            }
            if !surrounding.after.isEmpty {
                parts.append("Text after selection: \(surrounding.after)")
            }
        }
        if let fullVal = fullElementValue, selectedText == nil || fullVal.count > (selectedText?.count ?? 0) + 50 {
            parts.append("Full element text: \(fullVal)")
        }
        if !visibleElements.isEmpty {
            let lines = visibleElements.prefix(40).map { el in
                let indent = String(repeating: "  ", count: el.depth)
                let label = el.label ?? el.value.map { String($0.prefix(80)) } ?? ""
                return "\(indent)[\(el.role)] \(label)"
            }
            parts.append("Visible UI:\n" + lines.joined(separator: "\n"))
        }

        return parts.joined(separator: "\n\n")
    }

    static func makePromptContext(
        captureResult: SelectionCaptureResult,
        appName: String?,
        windowTitle: String?,
        focusedElementRole: String?,
        fullElementValue: String?,
        surroundingText: SurroundingText?,
        visibleElements: [VisibleElement]
    ) -> PromptContext {
        var candidates: [String] = []
        var dropped = 0
        var mode: CaptureMode = .axOnly

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
        } else if case .empty = captureResult {
            mode = .axOnly
        }

        if let surroundingText {
            let before = Self.cleanCandidate(surroundingText.before)
            let after = Self.cleanCandidate(surroundingText.after)
            if let before, !before.isEmpty {
                candidates.append("Text before focus:\n\(before)")
            }
            if let after, !after.isEmpty {
                candidates.append("Text after focus:\n\(after)")
            }
        }

        if let fullElementValue = cleanCandidate(fullElementValue) {
            candidates.append("Focused field text:\n\(fullElementValue)")
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
        }

        let deduped = dedupe(candidates)
        dropped += max(0, candidates.count - deduped.count)

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

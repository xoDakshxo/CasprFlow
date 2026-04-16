import Foundation

/// Everything we can scrape from the screen at hotkey time.
/// Structured so an AI consumer can reconstruct what the user sees and infer intent.
struct ScreenContext: Equatable {

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
}

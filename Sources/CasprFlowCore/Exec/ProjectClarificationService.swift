import AppKit
import Foundation

public struct ProjectClarificationService: Sendable {
    public init() {}

    public func clarifyProject(spokenName: String, candidates: [String]) async -> URL? {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Which project is \"\(spokenName)\"?"
            alert.informativeText = informativeText(for: candidates)
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Use Project")
            alert.addButton(withTitle: "Cancel")

            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 520, height: 24))
            field.stringValue = candidates.first ?? ""
            field.placeholderString = "/Users/you/Code/Project"
            alert.accessoryView = field

            let response = alert.runModal()
            guard response == .alertFirstButtonReturn,
                  let cleaned = SelectionTextNormalizer.clean(field.stringValue) else {
                return nil
            }

            let expanded = NSString(string: cleaned).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded).standardizedFileURL
            guard Self.isExistingDirectory(url) else {
                return nil
            }
            return url
        }
    }

    private static func isExistingDirectory(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    private func informativeText(for candidates: [String]) -> String {
        guard !candidates.isEmpty else {
            return "Type or paste the project folder path. CasprFlow will remember this spoken name next time."
        }

        return [
            "CasprFlow found possible matches. Keep or edit the path below.",
            candidates.prefix(4).joined(separator: "\n")
        ].joined(separator: "\n\n")
    }
}

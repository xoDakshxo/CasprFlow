import AppKit
@preconcurrency import ApplicationServices
import os.log

enum SelectionCaptureResult: Equatable {
    case selected(String)
    case empty
    case permissionRequired
}

@MainActor
final class SelectionCaptureService {
    private let permissionService: AccessibilityPermissionService

    init(permissionService: AccessibilityPermissionService) {
        self.permissionService = permissionService
    }

    // MARK: - Public

    func captureContext() async -> ScreenContext {
        guard permissionService.isTrusted else {
            Self.debugLog("Not trusted")
            return .empty
        }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName
        let bundleId = frontApp?.bundleIdentifier
        let pid = frontApp?.processIdentifier
        Self.debugLog("capture: app=\(appName ?? "?") pid=\(pid ?? 0)")

        let focusedElement: AXUIElement? = Self.focusedElement(pid: pid)

        // Window info
        let windowTitle = Self.captureWindowTitle(element: focusedElement, pid: pid)
        let allWindows = Self.captureAllWindows(pid: pid)

        // Focused element metadata
        let elementRole = focusedElement.flatMap { Self.str($0, kAXRoleAttribute) }
        let elementSubrole = focusedElement.flatMap { Self.str($0, kAXSubroleAttribute) }
        let elementDesc = focusedElement.flatMap { Self.str($0, kAXDescriptionAttribute) }
        let elementId = focusedElement.flatMap { Self.str($0, kAXIdentifierAttribute) }
        let docURL = focusedElement.flatMap { Self.str($0, kAXDocumentAttribute) }
            ?? Self.captureDocumentURL(pid: pid)

        // Full text value of focused element
        let rawFullValue = focusedElement.flatMap { Self.str($0, kAXValueAttribute) }
        let fullValue = rawFullValue.map { String($0.prefix(ScreenContext.maxFullValueLength)) }

        Self.debugLog("window=\"\(windowTitle ?? "?")\" role=\(elementRole ?? "?") windows=\(allWindows.count)")

        // Selection capture
        var captureResult: SelectionCaptureResult = .empty
        var surroundingText: ScreenContext.SurroundingText?

        if let element = focusedElement {
            let rawSelected = Self.str(element, kAXSelectedTextAttribute)
            let directSelection = rawSelected.flatMap(SelectionTextNormalizer.clean)

            if let directSelection {
                captureResult = .selected(directSelection)
                surroundingText = Self.captureSurroundingText(for: element)
                if surroundingText != nil && surroundingText!.selected.isEmpty {
                    surroundingText = ScreenContext.SurroundingText(
                        before: surroundingText!.before,
                        selected: directSelection,
                        after: surroundingText!.after
                    )
                }
                Self.debugLog("AX direct: \(directSelection.prefix(60))...")
            } else if let (rangeSelection, surrounding) = Self.selectedTextAndContextFromValueAndRange(element) {
                captureResult = .selected(rangeSelection)
                surroundingText = surrounding
                Self.debugLog("AX range fallback")
            }
        }

        if case .empty = captureResult {
            if let clipboardSelection = await Self.captureViaClipboard() {
                captureResult = .selected(clipboardSelection)
                Self.debugLog("Clipboard: \(clipboardSelection.prefix(60))...")
            } else {
                Self.debugLog("All capture methods failed")
            }
        }

        // Walk the AX tree of the focused window for visible elements
        let visibleElements = Self.walkVisibleElements(pid: pid)

        return ScreenContext(
            captureResult: captureResult,
            appName: appName,
            bundleIdentifier: bundleId,
            windowTitle: windowTitle,
            allWindows: allWindows,
            focusedElementRole: elementRole,
            focusedElementSubrole: elementSubrole,
            elementDescription: elementDesc,
            documentURL: docURL,
            elementIdentifier: elementId,
            fullElementValue: fullValue,
            surroundingText: surroundingText,
            visibleElements: visibleElements
        )
    }

    /// Legacy method for backward compatibility with tests.
    func captureSelectedText() async -> SelectionCaptureResult {
        let context = await captureContext()
        return context.captureResult
    }

    // MARK: - AX Tree Walking

    /// Walk the focused window's AX tree and collect visible elements with text.
    private static func walkVisibleElements(pid: pid_t?) -> [ScreenContext.VisibleElement] {
        guard let pid else { return [] }
        let appElement = AXUIElementCreateApplication(pid)

        // Get focused window
        var windowRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &windowRef
        )
        guard status == .success, let windowValue = windowRef else { return [] }
        let windowElement = windowValue as! AXUIElement

        var elements: [ScreenContext.VisibleElement] = []
        walkElement(windowElement, depth: 0, into: &elements)
        return elements
    }

    private static func walkElement(
        _ element: AXUIElement,
        depth: Int,
        into elements: inout [ScreenContext.VisibleElement]
    ) {
        guard depth <= ScreenContext.maxTreeDepth,
              elements.count < ScreenContext.maxVisibleElements else { return }

        let role = str(element, kAXRoleAttribute) ?? "unknown"
        let title = str(element, kAXTitleAttribute)
        let desc = str(element, kAXDescriptionAttribute)
        let value = str(element, kAXValueAttribute)
        let identifier = str(element, kAXIdentifierAttribute)

        // Pick the best label: title > description
        let label = title ?? desc

        // Only include elements that carry some text information
        let hasContent = label != nil || (value != nil && !isLayoutRole(role)) || identifier != nil
        if hasContent {
            let truncatedValue = value.map { String($0.prefix(ScreenContext.VisibleElement.maxValueLength)) }
            elements.append(ScreenContext.VisibleElement(
                role: role,
                label: label,
                value: truncatedValue,
                identifier: identifier,
                depth: depth
            ))
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        let childStatus = AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &childrenRef
        )
        guard childStatus == .success,
              let children = childrenRef as? [AXUIElement] else { return }

        for child in children {
            guard elements.count < ScreenContext.maxVisibleElements else { break }
            walkElement(child, depth: depth + 1, into: &elements)
        }
    }

    /// Roles that are layout containers — skip their value to avoid noise.
    private static func isLayoutRole(_ role: String) -> Bool {
        switch role {
        case "AXGroup", "AXSplitGroup", "AXScrollArea", "AXLayoutArea",
             "AXTabGroup", "AXToolbar", "AXList", "AXOutline", "AXTable",
             "AXWindow", "AXSheet", "AXDrawer":
            return true
        default:
            return false
        }
    }

    // MARK: - All Windows

    private static func captureAllWindows(pid: pid_t?) -> [ScreenContext.WindowInfo] {
        guard let pid else { return [] }
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement, kAXWindowsAttribute as CFString, &windowsRef
        )
        guard status == .success, let windows = windowsRef as? [AXUIElement] else { return [] }

        // Get focused window for comparison
        var focusedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &focusedRef
        )

        var infos: [ScreenContext.WindowInfo] = []
        for window in windows {
            guard let title = str(window, kAXTitleAttribute), !title.isEmpty else { continue }
            let isFocused = focusedRef != nil && CFEqual(window, focusedRef as CFTypeRef)
            infos.append(ScreenContext.WindowInfo(
                title: String(title.prefix(ScreenContext.maxWindowTitleLength)),
                isFocused: isFocused
            ))
        }
        return infos
    }

    // MARK: - Clipboard Fallback

    private static func captureViaClipboard() async -> String? {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        // Save existing clipboard to restore later
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var dict = [NSPasteboard.PasteboardType: Data]()
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []

        // Primary: osascript Cmd+C — works across Electron, Warp, native apps
        let copySuccess = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                proc.arguments = ["-e", "tell application \"System Events\" to keystroke \"c\" using command down"]
                proc.standardOutput = FileHandle.nullDevice
                proc.standardError = FileHandle.nullDevice
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    continuation.resume(returning: proc.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
        _ = copySuccess

        try? await Task.sleep(nanoseconds: 200_000_000)
        var newChangeCount = pasteboard.changeCount

        // Fallback: CGEvent Cmd+C
        if newChangeCount == previousChangeCount {
            let source = CGEventSource(stateID: .privateState)
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false) {
                keyDown.flags = .maskCommand
                keyUp.flags = .maskCommand
                keyDown.post(tap: .cgSessionEventTap)
                keyUp.post(tap: .cgSessionEventTap)
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
            newChangeCount = pasteboard.changeCount
        }

        let text: String?
        if newChangeCount != previousChangeCount {
            text = SelectionTextNormalizer.clean(pasteboard.string(forType: .string))
        } else {
            text = nil
        }

        // Restore original clipboard
        pasteboard.clearContents()
        for itemDict in savedItems {
            let item = NSPasteboardItem()
            for (type, data) in itemDict {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }

        return text
    }

    // MARK: - AX Element Discovery

    private static func focusedElement(pid: pid_t?) -> AXUIElement? {
        if let pid {
            let appElement = AXUIElementCreateApplication(pid)
            var focusedValue: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            )
            if status == .success,
               let focusedValue,
               CFGetTypeID(focusedValue) == AXUIElementGetTypeID() {
                return (focusedValue as! AXUIElement)
            }
        }

        let systemElement = AXUIElementCreateSystemWide()
        var systemFocused: CFTypeRef?
        let systemStatus = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &systemFocused
        )
        guard systemStatus == .success,
              let systemFocused,
              CFGetTypeID(systemFocused) == AXUIElementGetTypeID() else {
            return nil
        }
        return (systemFocused as! AXUIElement)
    }

    // MARK: - Text Extraction with Context

    private static func selectedTextAndContextFromValueAndRange(
        _ element: AXUIElement
    ) -> (String, ScreenContext.SurroundingText?)? {
        guard let fullText = str(element, kAXValueAttribute), !fullText.isEmpty else {
            return nil
        }

        var rangeValue: CFTypeRef?
        let rangeStatus = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &rangeValue
        )
        guard rangeStatus == .success, let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = rangeValue as! AXValue
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetType(axValue) == .cfRange,
              AXValueGetValue(axValue, .cfRange, &range),
              range.location >= 0, range.length > 0 else {
            return nil
        }

        let nsString = fullText as NSString
        guard range.location < nsString.length else { return nil }

        let selLength = min(range.length, nsString.length - range.location)
        guard selLength > 0 else { return nil }

        let selectedText = nsString.substring(with: NSRange(location: range.location, length: selLength))
        guard let cleaned = SelectionTextNormalizer.clean(selectedText) else { return nil }

        let maxLen = ScreenContext.SurroundingText.maxLength
        let selStart = range.location
        let selEnd = range.location + selLength

        let beforeStart = max(0, selStart - maxLen)
        let afterEnd = min(nsString.length, selEnd + maxLen)

        let before = nsString.substring(with: NSRange(location: beforeStart, length: selStart - beforeStart))
        let after = nsString.substring(with: NSRange(location: selEnd, length: afterEnd - selEnd))

        return (cleaned, ScreenContext.SurroundingText(before: before, selected: cleaned, after: after))
    }

    private static func captureSurroundingText(for element: AXUIElement) -> ScreenContext.SurroundingText? {
        guard let fullText = str(element, kAXValueAttribute), !fullText.isEmpty else {
            return nil
        }

        var rangeValue: CFTypeRef?
        let rangeStatus = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &rangeValue
        )

        let nsString = fullText as NSString
        let maxLen = ScreenContext.SurroundingText.maxLength

        guard rangeStatus == .success, let rangeRef = rangeValue else {
            let start = max(0, nsString.length - maxLen)
            return ScreenContext.SurroundingText(before: nsString.substring(from: start), selected: "", after: "")
        }

        let axValue = rangeRef as! AXValue
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetType(axValue) == .cfRange,
              AXValueGetValue(axValue, .cfRange, &range) else {
            let start = max(0, nsString.length - maxLen)
            return ScreenContext.SurroundingText(before: nsString.substring(from: start), selected: "", after: "")
        }

        let selStart = max(0, min(range.location, nsString.length))
        let selEnd = max(0, min(range.location + range.length, nsString.length))
        let beforeStart = max(0, selStart - maxLen)
        let afterEnd = min(nsString.length, selEnd + maxLen)

        let before = nsString.substring(with: NSRange(location: beforeStart, length: selStart - beforeStart))
        let selected = selEnd > selStart
            ? nsString.substring(with: NSRange(location: selStart, length: selEnd - selStart))
            : ""
        let after = nsString.substring(with: NSRange(location: selEnd, length: afterEnd - selEnd))

        return ScreenContext.SurroundingText(before: before, selected: selected, after: after)
    }

    // MARK: - Document URL

    private static func captureDocumentURL(pid: pid_t?) -> String? {
        guard let pid else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &windowRef
        )
        guard status == .success, let windowValue = windowRef else { return nil }
        return str(windowValue as! AXUIElement, kAXDocumentAttribute)
    }

    // MARK: - Window Title

    private static func captureWindowTitle(element: AXUIElement?, pid: pid_t?) -> String? {
        if let element, let title = windowTitleFromElement(element) {
            return truncate(title, max: ScreenContext.maxWindowTitleLength)
        }
        guard let pid else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &windowRef
        )
        guard status == .success, let windowValue = windowRef else { return nil }
        return str(windowValue as! AXUIElement, kAXTitleAttribute)
            .flatMap { truncate($0, max: ScreenContext.maxWindowTitleLength) }
    }

    private static func windowTitleFromElement(_ element: AXUIElement) -> String? {
        var windowRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &windowRef)
        guard status == .success, let windowValue = windowRef else { return nil }
        return str(windowValue as! AXUIElement, kAXTitleAttribute)
    }

    private static func truncate(_ text: String, max: Int) -> String? {
        guard !text.isEmpty else { return nil }
        return text.count > max ? String(text.prefix(max)) : text
    }

    // MARK: - AX Helpers

    /// Shorthand for copying a string attribute from an AX element.
    private static func str(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success else { return nil }
        if let string = value as? String { return string }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }

    // MARK: - Logging

    private static let log = Logger(subsystem: "com.casprflow.CasprFlow", category: "capture")
    private static let verbose: Bool = ProcessInfo.processInfo.environment["CASPRFLOW_DEBUG"] == "1"

    private static let logFile: URL? = {
        guard verbose else { return nil }
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".casprflow-debug.log")
        try? "".write(to: path, atomically: true, encoding: .utf8)
        return path
    }()

    static func debugLog(_ message: String) {
        log.debug("\(message, privacy: .public)")
        guard verbose, let logFile else { return }
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        if let data = line.data(using: .utf8),
           let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    }
}

// MARK: - Empty context helper

extension ScreenContext {
    static let empty = ScreenContext(
        captureResult: .permissionRequired,
        appName: nil, bundleIdentifier: nil,
        windowTitle: nil, allWindows: [],
        focusedElementRole: nil, focusedElementSubrole: nil,
        elementDescription: nil, documentURL: nil,
        elementIdentifier: nil, fullElementValue: nil,
        surroundingText: nil, visibleElements: []
    )
}

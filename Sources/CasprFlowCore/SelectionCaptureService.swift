import AppKit
@preconcurrency import ApplicationServices

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

    func captureSelectedText() async -> SelectionCaptureResult {
        guard permissionService.isTrusted else {
            NSLog("[CasprFlow] Not trusted for accessibility")
            return .permissionRequired
        }
        NSLog("[CasprFlow] Accessibility trusted")

        let frontApp = NSWorkspace.shared.frontmostApplication
        NSLog("[CasprFlow] Frontmost app: %@ (pid: %d)", frontApp?.localizedName ?? "nil", frontApp?.processIdentifier ?? 0)

        // Try AX direct selection first (works for native Cocoa text views)
        if let focusedElement = Self.focusedElement() {
            NSLog("[CasprFlow] Got focused element")

            if let directSelection = Self.copyStringAttribute(
                focusedElement,
                kAXSelectedTextAttribute as CFString
            ).flatMap(SelectionTextNormalizer.clean) {
                NSLog("[CasprFlow] Direct AX selection succeeded")
                return .selected(directSelection)
            }

            if let rangeSelection = Self.selectedTextFromValueAndRange(focusedElement) {
                NSLog("[CasprFlow] Range fallback succeeded")
                return .selected(rangeSelection)
            }
            NSLog("[CasprFlow] AX methods failed, trying clipboard fallback")
        } else {
            NSLog("[CasprFlow] No focused element, trying clipboard fallback")
        }

        // Clipboard-based fallback for apps that don't expose AX selection
        if let clipboardSelection = await Self.captureViaClipboard() {
            NSLog("[CasprFlow] Clipboard fallback succeeded")
            return .selected(clipboardSelection)
        }

        NSLog("[CasprFlow] No selection found via any method")
        return .empty
    }

    private static func captureViaClipboard() async -> String? {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        // Save existing clipboard contents
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var dict = [NSPasteboard.PasteboardType: Data]()
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false) else {
            return nil
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // Wait for the clipboard to update
        try? await Task.sleep(nanoseconds: 80_000_000) // 80ms

        let text: String?
        if pasteboard.changeCount != previousChangeCount {
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

    private static func focusedElement() -> AXUIElement? {
        if let element = focusedElementFromFrontmostApplication() {
            return element
        }

        return focusedElementFromSystemWide()
    }

    private static func focusedElementFromFrontmostApplication() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard status == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return nil
        }

        return focusedValue as! AXUIElement
    }

    private static func focusedElementFromSystemWide() -> AXUIElement? {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard status == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return nil
        }

        return focusedValue as! AXUIElement
    }

    private static func selectedTextFromValueAndRange(_ element: AXUIElement) -> String? {
        guard let fullText = copyStringAttribute(element, kAXValueAttribute as CFString),
              !fullText.isEmpty else {
            return nil
        }

        var rangeValue: CFTypeRef?
        let rangeStatus = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )

        guard rangeStatus == .success,
              let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = rangeValue as! AXValue
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetType(axValue) == .cfRange,
              AXValueGetValue(axValue, .cfRange, &range),
              range.location >= 0,
              range.length > 0 else {
            return nil
        }

        let nsString = fullText as NSString
        guard range.location < nsString.length else {
            return nil
        }

        let length = min(range.length, nsString.length - range.location)
        guard length > 0 else {
            return nil
        }

        return SelectionTextNormalizer.clean(
            nsString.substring(with: NSRange(location: range.location, length: length))
        )
    }

    private static func copyStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        if let attributedString = value as? NSAttributedString {
            return attributedString.string
        }

        return nil
    }
}

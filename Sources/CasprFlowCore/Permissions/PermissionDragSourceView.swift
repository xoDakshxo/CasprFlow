import AppKit

@MainActor
final class PermissionDragSourceView: NSView, NSPasteboardItemDataProvider, NSDraggingSource {
    private let bundleURL: URL
    private let appName: String
    private let appIcon: NSImage
    private var isDragging = false

    init(bundleURL: URL, appName: String, appIcon: NSImage) {
        self.bundleURL = bundleURL
        self.appName = appName
        self.appIcon = appIcon
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 48))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 445, height: 43)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        startDrag(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !isDragging else { return }

        let rowBounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let rowPath = NSBezierPath(roundedRect: rowBounds, xRadius: 7, yRadius: 7)
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            NSColor.white.withAlphaComponent(0.06).setFill()
        } else {
            NSColor.white.withAlphaComponent(0.65).setFill()
        }
        rowPath.fill()

        if isDark {
            NSColor.white.withAlphaComponent(0.08).setStroke()
        } else {
            NSColor(red: 0.87451, green: 0.866667, blue: 0.862745, alpha: 1).setStroke()
        }
        rowPath.lineWidth = 1
        rowPath.stroke()

        let iconChrome = NSBezierPath(
            roundedRect: NSRect(x: 10, y: (bounds.height - 26) / 2, width: 26, height: 26),
            xRadius: 6,
            yRadius: 6
        )
        NSColor.white.withAlphaComponent(0.9).setFill()
        iconChrome.fill()

        let iconRect = NSRect(x: 12, y: (bounds.height - 22) / 2, width: 22, height: 22)
        appIcon.draw(in: iconRect)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.82)
        ]

        NSString(string: appName).draw(
            in: NSRect(x: 47, y: 12, width: bounds.width - 59, height: 20),
            withAttributes: titleAttributes
        )
    }

    nonisolated static func pasteboardTypes(for bundleURL: URL) -> [NSPasteboard.PasteboardType] {
        _ = bundleURL
        return [.fileURL]
    }

    private func startDrag(with event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setDataProvider(self, forTypes: [.fileURL])

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: dragImage())
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    private func dragImage() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        draw(bounds)
        image.unlockFocus()
        return image
    }

    func pasteboard(
        _ pasteboard: NSPasteboard?,
        item: NSPasteboardItem,
        provideDataForType type: NSPasteboard.PasteboardType
    ) {
        guard type == .fileURL else { return }
        item.setData(bundleURL.dataRepresentation, forType: .fileURL)
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        isDragging = true
        needsDisplay = true
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        isDragging = false
        needsDisplay = true
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }
}

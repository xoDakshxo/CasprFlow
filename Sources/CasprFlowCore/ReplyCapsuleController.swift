import AppKit
import SwiftUI

@MainActor
final class ReplyCapsuleController {
    private let panel: ReplyCapsulePanel
    private let hostingView: NSHostingView<ReplyCapsulePlaceholderView>

    init() {
        let contentSize = NSSize(width: 360, height: 132)
        panel = ReplyCapsulePanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        hostingView = NSHostingView(
            rootView: ReplyCapsulePlaceholderView(title: "CasprFlow", message: "Ready.")
        )
        hostingView.frame = NSRect(origin: .zero, size: contentSize)

        panel.contentView = hostingView
        panel.onEscape = { [weak self] in
            self?.hide()
        }
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
    }

    func show(title: String, message: String) {
        hostingView.rootView = ReplyCapsulePlaceholderView(title: title, message: message)
        positionNearTopCenter()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionNearTopCenter() {
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 84
        let size = panel.frame.size
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height - margin
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }
}

private final class ReplyCapsulePanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}

struct ReplyCapsulePlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Text("Esc to close")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 360, height: 132, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }
}


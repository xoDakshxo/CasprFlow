import AppKit
import SwiftUI

/// Borderless, floating, non-activating panel. The shared window shell for
/// CasprFlow's on-screen surfaces: the center-bottom **voice HUD** and the future
/// always-on-top **artifact window**.
///
/// Extracted from the retired reply-capsule shell. Create it once at launch and
/// reuse it (show/hide) so invoking the hotkey costs no allocation. Escape calls
/// `onEscape`.
public final class FloatingPanel: NSPanel {
    public var onEscape: (() -> Void)?
    public var allowsKeyFocus = true

    public override var canBecomeKey: Bool { allowsKeyFocus }
    public override var canBecomeMain: Bool { false }

    /// Build a configured floating panel of the given content size.
    public static func make(size: NSSize, canBecomeKey: Bool = true) -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.allowsKeyFocus = canBecomeKey
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        return panel
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

    /// Place the panel small and centered near the **bottom** of the screen holding
    /// the mouse — the Wispr-style voice HUD position.
    public func positionCenterBottom(bottomInset: CGFloat = 120) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }

        let size = self.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + bottomInset
        )
        setFrameOrigin(origin)
    }
}

/// Temporary placeholder content for the HUD. Replaced in phase 1 by the live
/// transcript readout that transitions into the `CasprFlowLogoMark` spinner.
public struct HUDPlaceholderView: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 8) {
            CasprFlowLogoMark(size: 16)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
    }
}

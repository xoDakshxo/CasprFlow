import AppKit
import SwiftUI

@MainActor
final class PermissionGuideController {
    private let accessibilityPermissionService: AccessibilityPermissionService
    private let screenRecordingPermissionService: ScreenRecordingPermissionService
    private let onPermissionStateChanged: () -> Void
    private var activePanel: PermissionGuidePanel?
    private var guideWindow: PermissionGuideWindow?
    private var hostingView: NSHostingView<PermissionGuideView>?
    private var pollTimer: Timer?

    init(
        accessibilityPermissionService: AccessibilityPermissionService,
        screenRecordingPermissionService: ScreenRecordingPermissionService,
        onPermissionStateChanged: @escaping () -> Void
    ) {
        self.accessibilityPermissionService = accessibilityPermissionService
        self.screenRecordingPermissionService = screenRecordingPermissionService
        self.onPermissionStateChanged = onPermissionStateChanged
    }

    func present(panel: PermissionGuidePanel) {
        activePanel = panel
        panel.openSystemSettings()
        startPolling()
        onPermissionStateChanged()
    }

    func dismiss() {
        pollTimer?.invalidate()
        pollTimer = nil
        activePanel = nil
        guideWindow?.orderOut(nil)
        guideWindow = nil
        hostingView = nil
        onPermissionStateChanged()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
        poll()
    }

    private func poll() {
        guard let panel = activePanel else {
            dismiss()
            return
        }

        if isGranted(panel) {
            dismiss()
            return
        }

        refreshOverlay()
    }

    private func refreshOverlay() {
        guard let panel = activePanel else { return }
        guard let snapshot = SystemSettingsWindowLocator.frontmostWindow() else {
            guideWindow?.orderOut(nil)
            return
        }

        let identity = PermissionAppIdentity.current()
        let size = NSSize(width: 530, height: 109)
        let view = PermissionGuideView(
            panel: panel,
            appIdentity: identity,
            onClose: { [weak self] in self?.dismiss() },
            onOpenSettings: { panel.openSystemSettings() }
        )

        if let hostingView {
            hostingView.rootView = view
        } else {
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(origin: .zero, size: size)
            self.hostingView = hostingView

            let window = PermissionGuideWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = hostingView
            window.setContentSize(size)
            self.guideWindow = window
        }

        guideWindow?.setFrame(positionedFrame(size: size, snapshot: snapshot), display: true)
        guideWindow?.orderFrontRegardless()
    }

    private func isGranted(_ panel: PermissionGuidePanel) -> Bool {
        switch panel {
        case .accessibility:
            return accessibilityPermissionService.isTrustedWithoutLogging
        case .screenRecording:
            return screenRecordingPermissionService.isGranted
        }
    }

    private func positionedFrame(size: NSSize, snapshot: SystemSettingsWindowSnapshot) -> NSRect {
        let settingsFrame = snapshot.frame
        let visibleFrame = snapshot.visibleFrame
        let sidebarWidth: CGFloat = 170
        let contentMinX = settingsFrame.minX + sidebarWidth
        let contentWidth = max(settingsFrame.width - sidebarWidth, size.width)
        let preferredX = contentMinX + ((contentWidth - size.width) / 2) - 8
        let preferredY = settingsFrame.minY + 14
        let minX = visibleFrame.minX + 8
        let maxX = visibleFrame.maxX - size.width - 8
        let minY = visibleFrame.minY + 8
        let maxY = visibleFrame.maxY - size.height - 8

        return NSRect(
            x: min(max(preferredX, minX), maxX),
            y: min(max(preferredY, minY), maxY),
            width: size.width,
            height: size.height
        )
    }
}

private final class PermissionGuideWindow: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct PermissionAppIdentity {
    let appName: String
    let bundleURL: URL
    let icon: NSImage

    static func current() -> PermissionAppIdentity {
        let bundle = Bundle.main
        let bundleURL = NSRunningApplication.current.bundleURL ?? bundle.bundleURL
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundleURL.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 32, height: 32)
        return PermissionAppIdentity(appName: appName, bundleURL: bundleURL, icon: icon)
    }
}

private struct PermissionGuideView: View {
    let panel: PermissionGuidePanel
    let appIdentity: PermissionAppIdentity
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.78))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 0.5)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.15, green: 0.54, blue: 0.98, alpha: 1)))
                        .frame(width: 28, height: 28)

                    Text("Drag \(appIdentity.appName) to the list above to allow \(panel.shortName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.82))
                        .lineLimit(1)
                }
                .padding(.leading, 35)
                .padding(.top, 10)

                HStack(spacing: 14) {
                    Button {
                        onClose()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.95))
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.72))
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)

                    PermissionDragSourceRepresentable(appIdentity: appIdentity)
                        .frame(height: 43)
                }
                .padding(.leading, 18)
                .padding(.trailing, 21)
            }
        }
        .frame(width: 530, height: 109)
    }
}

private struct PermissionDragSourceRepresentable: NSViewRepresentable {
    let appIdentity: PermissionAppIdentity

    func makeNSView(context: Context) -> PermissionDragSourceView {
        PermissionDragSourceView(
            bundleURL: appIdentity.bundleURL,
            appName: appIdentity.appName,
            appIcon: appIdentity.icon
        )
    }

    func updateNSView(_ nsView: PermissionDragSourceView, context: Context) {
        nsView.needsDisplay = true
    }
}

import AppKit
import SwiftUI

/// Top-level wiring for the CasprFlow menu-bar app.
///
/// This is the post-pivot skeleton: it registers the global hotkey, owns the
/// permission + status-item plumbing, and shows a prewarmed command-bar panel.
/// The dispatcher itself (input field, intent router, action handlers) is wired
/// in on top of this shell during the implementation phases — see
/// `docs/implementation/`.
@MainActor
final class AppCoordinator {
    private let hotkeyService = HotkeyService()
    private let permissionService = AccessibilityPermissionService()
    private let screenRecordingPermissionService = ScreenRecordingPermissionService()
    private lazy var permissionGuideController = PermissionGuideController(
        accessibilityPermissionService: permissionService,
        screenRecordingPermissionService: screenRecordingPermissionService,
        onPermissionStateChanged: { [weak self] in
            self?.statusItemController?.refresh()
        }
    )

    /// Prewarmed once at launch so invoking the hotkey costs no allocation.
    /// The small center-bottom voice HUD (sine-wave listening → spinner).
    private let hud: FloatingPanel
    private let hudHostingView: NSHostingView<AnyView>
    private var statusItemController: StatusItemController?
    private var isEnabled = true
    private var isListening = false

    init() {
        let size = NSSize(width: 240, height: 56)
        hud = FloatingPanel.make(size: size)
        hudHostingView = NSHostingView(
            rootView: AnyView(HUDPlaceholderView(message: "Ready"))
        )
        hudHostingView.frame = NSRect(origin: .zero, size: size)
        hud.contentView = hudHostingView
        hud.onEscape = { [weak self] in self?.dismissHUD() }
    }

    func start() {
        statusItemController = StatusItemController(
            onToggleEnabled: { [weak self] in self?.toggleEnabled() },
            onRequestAccessibility: { [weak self] in self?.showPermissionGuide(.accessibility) },
            onRequestScreenRecording: { [weak self] in self?.showPermissionGuide(.screenRecording) },
            onQuit: { NSApp.terminate(nil) },
            stateProvider: { [weak self] in
                StatusItemState(
                    isEnabled: self?.isEnabled ?? false,
                    isAccessibilityTrusted: self?.permissionService.isTrusted ?? false,
                    isScreenRecordingGranted: self?.screenRecordingPermissionService.isGranted ?? false
                )
            }
        )

        // Point first-run setup at the exact permission pane.
        if !permissionService.isTrusted {
            permissionGuideController.present(panel: .accessibility)
        }

        registerHotkey()
    }

    func stop() {
        hotkeyService.unregister()
        permissionGuideController.dismiss()
    }

    private func registerHotkey() {
        do {
            // Push-to-talk: hold = listen, release = process.
            try hotkeyService.registerDefaultHotkey(
                onPress: { [weak self] in self?.startListening() },
                onRelease: { [weak self] in self?.stopListening() }
            )
        } catch {
            NSLog("[CasprFlow] Hotkey registration failed: %@", String(describing: error))
        }
    }

    private func toggleEnabled() {
        isEnabled.toggle()
        statusItemController?.refresh()
        if !isEnabled { dismissHUD() }
    }

    /// Hotkey pressed: show the center-bottom HUD and (once wired) begin on-device
    /// speech capture with the live sine-wave animation. See phase 1.
    private func startListening() {
        guard isEnabled, !isListening else { return }
        isListening = true
        setHUD(message: "Listening…")
        hud.positionCenterBottom()
        hud.orderFrontRegardless()
    }

    /// Hotkey released: stop capture, show the spinner while the transcript is routed
    /// and dispatched. The skeleton just flashes the spinner and dismisses.
    private func stopListening() {
        guard isListening else { return }
        isListening = false
        setHUD(message: "Working…")
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            self?.dismissHUD()
        }
    }

    private func setHUD(message: String) {
        hudHostingView.rootView = AnyView(HUDPlaceholderView(message: message))
    }

    private func dismissHUD() {
        hud.orderOut(nil)
        isListening = false
    }

    private func showPermissionGuide(_ panel: PermissionGuidePanel) {
        permissionGuideController.present(panel: panel)
        statusItemController?.refresh()
    }
}

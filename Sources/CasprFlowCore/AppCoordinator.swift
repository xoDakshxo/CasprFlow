import AppKit

/// Top-level wiring for the CasprFlow menu-bar app.
///
/// This is the post-pivot skeleton: it registers the global hotkey, owns the
/// permission + status-item plumbing, and owns the prewarmed voice HUD. The
/// route→dispatch loop is wired in on top of this shell during later phases.
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

    private let voiceHUDController: VoiceHUDController
    private var statusItemController: StatusItemController?
    private var isEnabled = true

    init() {
        voiceHUDController = VoiceHUDController { transcript in
            let loggedTranscript = transcript.isEmpty ? "<empty>" : transcript
            NSLog("[CasprFlow] Voice transcript: %@", loggedTranscript)
        }
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
        NSLog("[CasprFlow] Status item initialized")

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
            NSLog("[CasprFlow] Hotkey registered: %@", HotkeyDescriptor.defaultHotkey.displayName)
        } catch {
            NSLog("[CasprFlow] Hotkey registration failed: %@", String(describing: error))
        }
    }

    private func toggleEnabled() {
        isEnabled.toggle()
        statusItemController?.refresh()
        if !isEnabled { voiceHUDController.dismiss() }
    }

    /// Hotkey pressed: show the center-bottom transcript HUD and begin on-device capture.
    private func startListening() {
        guard isEnabled else { return }
        NSLog("[CasprFlow] Push-to-talk press")
        voiceHUDController.beginListening()
    }

    /// Hotkey released: show the spinner immediately and log the finalized transcript.
    private func stopListening() {
        guard isEnabled else { return }
        NSLog("[CasprFlow] Push-to-talk release")
        voiceHUDController.endListening()
    }

    private func showPermissionGuide(_ panel: PermissionGuidePanel) {
        permissionGuideController.present(panel: panel)
        statusItemController?.refresh()
    }
}

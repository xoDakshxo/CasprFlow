import AppKit

@MainActor
final class AppCoordinator {
    private let hotkeyService = HotkeyService()
    private let permissionService = AccessibilityPermissionService()
    private let screenRecordingPermissionService = ScreenRecordingPermissionService()
    private lazy var selectionCaptureService = SelectionCaptureService(permissionService: permissionService)
    private lazy var permissionGuideController = PermissionGuideController(
        accessibilityPermissionService: permissionService,
        screenRecordingPermissionService: screenRecordingPermissionService,
        onPermissionStateChanged: { [weak self] in
            self?.statusItemController?.refresh()
        }
    )
    private let capsuleController = ReplyCapsuleController()
    private var statusItemController: StatusItemController?
    private var isEnabled = true

    func start() {
        statusItemController = StatusItemController(
            onToggleEnabled: { [weak self] in self?.toggleEnabled() },
            onClearLearning: { [weak self] in self?.showLearningCleared() },
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

        // Keep first-run setup pointed at the exact permission pane.
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
            try hotkeyService.registerDefaultHotkey { [weak self] in
                self?.handleHotkey()
            }
        } catch {
            capsuleController.show(
                title: "Hotkey unavailable",
                message: "Option + Space could not be registered."
            )
        }
    }

    private func toggleEnabled() {
        isEnabled.toggle()
        statusItemController?.refresh()
        if !isEnabled {
            capsuleController.hide()
        }
    }

    private func handleHotkey() {
        guard isEnabled else { return }
        NSLog("[CasprFlow] Hotkey fired")
        Task { @MainActor [weak self] in
            await self?.captureSelectionAndShowCapsule()
        }
    }

    private func captureSelectionAndShowCapsule() async {
        let context = await selectionCaptureService.captureContext()
        NSLog("[CasprFlow] Capture result: %@", String(describing: context.captureResult))
        switch context.captureResult {
        case .permissionRequired:
            showPermissionGuide(.accessibility)
            capsuleController.show(
                title: "Accessibility needed",
                message: "Use the menu helper to add CasprFlow, then press Option + Space again."
            )
        case .selected, .empty:
            if !context.bundle.prompt.isEmpty {
                capsuleController.showContext(context)
            } else {
                capsuleController.show(
                    title: "Need more context",
                    message: "Focus a reply field with visible message text, then press Option + Space."
                )
            }
        }
    }

    private func showLearningCleared() {
        capsuleController.show(
            title: "Learning cleared",
            message: "Nothing to clear yet."
        )
    }

    private func showPermissionGuide(_ panel: PermissionGuidePanel) {
        permissionGuideController.present(panel: panel)
        statusItemController?.refresh()
    }

}

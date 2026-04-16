import AppKit

@MainActor
final class AppCoordinator {
    private let hotkeyService = HotkeyService()
    private let permissionService = AccessibilityPermissionService()
    private lazy var selectionCaptureService = SelectionCaptureService(permissionService: permissionService)
    private let capsuleController = ReplyCapsuleController()
    private var statusItemController: StatusItemController?
    private var isEnabled = true

    func start() {
        statusItemController = StatusItemController(
            onToggleEnabled: { [weak self] in self?.toggleEnabled() },
            onClearLearning: { [weak self] in self?.showLearningCleared() },
            onRequestAccessibility: { [weak self] in self?.permissionService.requestAccess() },
            onQuit: { NSApp.terminate(nil) },
            stateProvider: { [weak self] in
                StatusItemState(
                    isEnabled: self?.isEnabled ?? false,
                    isAccessibilityTrusted: self?.permissionService.isTrusted ?? false
                )
            }
        )

        // Prompt for accessibility on launch if not trusted
        if !permissionService.isTrusted {
            permissionService.requestAccess()
        }

        registerHotkey()
    }

    func stop() {
        hotkeyService.unregister()
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
        case .selected:
            capsuleController.showContext(context)
        case .empty:
            capsuleController.show(title: "CasprFlow", message: "Highlight a message first.")
        case .permissionRequired:
            capsuleController.show(
                title: "Accessibility needed",
                message: "Allow CasprFlow in Accessibility, then highlight a message."
            )
        }
    }

    private func showLearningCleared() {
        capsuleController.show(
            title: "Learning cleared",
            message: "Nothing to clear yet."
        )
    }

}

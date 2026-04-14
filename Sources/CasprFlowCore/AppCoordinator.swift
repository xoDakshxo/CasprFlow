import AppKit

@MainActor
final class AppCoordinator {
    private let hotkeyService = HotkeyService()
    private let permissionService = AccessibilityPermissionService()
    private let capsuleController = ReplyCapsuleController()
    private var statusItemController: StatusItemController?
    private var isEnabled = true

    func start() {
        statusItemController = StatusItemController(
            onToggleEnabled: { [weak self] in self?.toggleEnabled() },
            onClearLearning: { [weak self] in self?.showLearningCleared() },
            onOpenAccessibility: { [weak self] in self?.permissionService.openSystemSettings() },
            onQuit: { NSApp.terminate(nil) },
            stateProvider: { [weak self] in
                StatusItemState(
                    isEnabled: self?.isEnabled ?? false,
                    isAccessibilityTrusted: self?.permissionService.isTrusted ?? false
                )
            }
        )

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
        capsuleController.show(
            title: "CasprFlow",
            message: permissionMessage
        )
    }

    private func showLearningCleared() {
        capsuleController.show(
            title: "Learning cleared",
            message: "Nothing to clear yet."
        )
    }

    private var permissionMessage: String {
        if permissionService.isTrusted {
            return "Ready for Phase 2: selected text capture."
        }
        return "Ready. Accessibility permission will be needed for capture and paste."
    }
}


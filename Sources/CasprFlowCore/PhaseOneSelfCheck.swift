import AppKit

public enum PhaseOneSelfCheck {
    @MainActor
    public static func canRegisterDefaultHotkey() -> Bool {
        let service = HotkeyService()
        do {
            try service.registerDefaultHotkey {}
            service.unregister()
            return true
        } catch {
            service.unregister()
            return false
        }
    }

    @MainActor
    public static func canCreateReplyCapsule() -> Bool {
        _ = NSApplication.shared
        _ = ReplyCapsuleController()
        return true
    }
}


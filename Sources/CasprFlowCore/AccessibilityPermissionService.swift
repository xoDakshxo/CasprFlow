import ApplicationServices
import AppKit

@MainActor
final class AccessibilityPermissionService {
    var isTrusted: Bool {
        Self.checkTrust(prompt: false)
    }

    func requestAccess() {
        _ = Self.checkTrust(prompt: true)
        openSystemSettings()
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private nonisolated static func checkTrust(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

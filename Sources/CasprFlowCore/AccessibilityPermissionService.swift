@preconcurrency import ApplicationServices
import AppKit

@MainActor
final class AccessibilityPermissionService {
    var isTrusted: Bool {
        let trusted = Self.checkTrust(prompt: false)
        NSLog("[CasprFlow] AXIsProcessTrusted: %@, pid: %d, bundle: %@",
              trusted ? "YES" : "NO",
              ProcessInfo.processInfo.processIdentifier,
              Bundle.main.bundleIdentifier ?? "none")
        return trusted
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

    @MainActor
    private static func checkTrust(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

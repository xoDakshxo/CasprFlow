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

    var isTrustedWithoutLogging: Bool {
        Self.checkTrust(prompt: false)
    }

    func requestAccess() {
        _ = Self.checkTrust(prompt: true)
        openSystemSettings()
    }

    func openSystemSettings() {
        PermissionGuidePanel.accessibility.openSystemSettings()
    }

    @MainActor
    private static func checkTrust(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

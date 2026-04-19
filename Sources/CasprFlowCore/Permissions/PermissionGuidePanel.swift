import AppKit

public enum PermissionGuidePanel: String, CaseIterable, Sendable {
    case accessibility
    case screenRecording

    public var settingsPaneIdentifier: String {
        switch self {
        case .accessibility:
            return "Privacy_Accessibility"
        case .screenRecording:
            return "Privacy_ScreenCapture"
        }
    }

    var title: String {
        switch self {
        case .accessibility:
            return "Enable Accessibility"
        case .screenRecording:
            return "Enable Screen Recording"
        }
    }

    var grantedTitle: String {
        switch self {
        case .accessibility:
            return "Accessibility is enabled"
        case .screenRecording:
            return "Screen Recording is enabled"
        }
    }

    var shortName: String {
        switch self {
        case .accessibility:
            return "Accessibility"
        case .screenRecording:
            return "Screen Recording"
        }
    }

    var reason: String {
        switch self {
        case .accessibility:
            return "Needed for the hotkey, focus restore, and paste flow."
        case .screenRecording:
            return "Needed so Caspr can read the visible screen context."
        }
    }

    var instruction: String {
        "Drag CasprFlow into the \(shortName) list, then enable the switch."
    }

    var settingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(settingsPaneIdentifier)")!
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(settingsURL)
    }
}

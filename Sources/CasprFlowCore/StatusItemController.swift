import AppKit

public struct StatusItemState: Equatable, Sendable {
    public let isEnabled: Bool
    public let isAccessibilityTrusted: Bool

    public init(isEnabled: Bool, isAccessibilityTrusted: Bool) {
        self.isEnabled = isEnabled
        self.isAccessibilityTrusted = isAccessibilityTrusted
    }
}

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let onToggleEnabled: () -> Void
    private let onClearLearning: () -> Void
    private let onOpenAccessibility: () -> Void
    private let onQuit: () -> Void
    private let stateProvider: () -> StatusItemState

    init(
        onToggleEnabled: @escaping () -> Void,
        onClearLearning: @escaping () -> Void,
        onOpenAccessibility: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        stateProvider: @escaping () -> StatusItemState
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onToggleEnabled = onToggleEnabled
        self.onClearLearning = onClearLearning
        self.onOpenAccessibility = onOpenAccessibility
        self.onQuit = onQuit
        self.stateProvider = stateProvider
        super.init()

        if let button = statusItem.button {
            button.title = "CF"
            button.toolTip = "CasprFlow"
        }
        refresh()
    }

    func refresh() {
        let state = stateProvider()
        let menu = NSMenu()

        let enabledItem = NSMenuItem(
            title: state.isEnabled ? "Disable CasprFlow" : "Enable CasprFlow",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        menu.addItem(enabledItem)

        let hotkeyItem = NSMenuItem(title: "Hotkey: Option + Space", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        let permissionItem = NSMenuItem(
            title: state.isAccessibilityTrusted ? "Accessibility: Granted" : "Accessibility: Needed soon",
            action: #selector(openAccessibility),
            keyEquivalent: ""
        )
        permissionItem.target = self
        permissionItem.isEnabled = !state.isAccessibilityTrusted
        menu.addItem(permissionItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(
            title: "Clear learning",
            action: #selector(clearLearning),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        onToggleEnabled()
    }

    @objc private func clearLearning() {
        onClearLearning()
    }

    @objc private func openAccessibility() {
        onOpenAccessibility()
    }

    @objc private func quit() {
        onQuit()
    }
}

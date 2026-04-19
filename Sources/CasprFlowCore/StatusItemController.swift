import AppKit

public struct StatusItemState: Equatable, Sendable {
    public let isEnabled: Bool
    public let isAccessibilityTrusted: Bool
    public let isScreenRecordingGranted: Bool

    public init(
        isEnabled: Bool,
        isAccessibilityTrusted: Bool,
        isScreenRecordingGranted: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.isScreenRecordingGranted = isScreenRecordingGranted
    }
}

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let onToggleEnabled: () -> Void
    private let onClearLearning: () -> Void
    private let onRequestAccessibility: () -> Void
    private let onRequestScreenRecording: () -> Void
    private let onQuit: () -> Void
    private let stateProvider: () -> StatusItemState

    init(
        onToggleEnabled: @escaping () -> Void,
        onClearLearning: @escaping () -> Void,
        onRequestAccessibility: @escaping () -> Void,
        onRequestScreenRecording: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        stateProvider: @escaping () -> StatusItemState
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onToggleEnabled = onToggleEnabled
        self.onClearLearning = onClearLearning
        self.onRequestAccessibility = onRequestAccessibility
        self.onRequestScreenRecording = onRequestScreenRecording
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

        let accessibilityItem = NSMenuItem(
            title: Self.accessibilityMenuTitle(isGranted: state.isAccessibilityTrusted),
            action: #selector(openAccessibility),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        accessibilityItem.isEnabled = !state.isAccessibilityTrusted
        menu.addItem(accessibilityItem)

        let screenRecordingItem = NSMenuItem(
            title: Self.screenRecordingMenuTitle(isGranted: state.isScreenRecordingGranted),
            action: #selector(openScreenRecording),
            keyEquivalent: ""
        )
        screenRecordingItem.target = self
        screenRecordingItem.isEnabled = !state.isScreenRecordingGranted
        menu.addItem(screenRecordingItem)

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

    nonisolated static func accessibilityMenuTitle(isGranted: Bool) -> String {
        isGranted ? "Accessibility: Granted" : "Enable Accessibility..."
    }

    nonisolated static func screenRecordingMenuTitle(isGranted: Bool) -> String {
        isGranted ? "Screen Recording: Granted" : "Enable Screen Recording..."
    }

    @objc private func toggleEnabled() {
        onToggleEnabled()
    }

    @objc private func clearLearning() {
        onClearLearning()
    }

    @objc private func openAccessibility() {
        onRequestAccessibility()
    }

    @objc private func openScreenRecording() {
        onRequestScreenRecording()
    }

    @objc private func quit() {
        onQuit()
    }
}

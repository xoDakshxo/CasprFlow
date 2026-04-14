import CasprFlowCore
import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Check failed: \(message)\n", stderr)
        exit(1)
    }
}

expect(HotkeyDescriptor.defaultHotkey.displayName == "Option + Space", "default hotkey label")
expect(HotkeyDescriptor.defaultHotkey.keyCode == 49, "default hotkey key code")
expect(HotkeyDescriptor.defaultHotkey.carbonModifiers == 2048, "default hotkey modifier")

let state = StatusItemState(isEnabled: true, isAccessibilityTrusted: false)
expect(state.isEnabled, "status item enabled flag")
expect(!state.isAccessibilityTrusted, "status item accessibility flag")

Task { @MainActor in
    expect(PhaseOneSelfCheck.canCreateReplyCapsule(), "reply capsule construction")
    expect(PhaseOneSelfCheck.canRegisterDefaultHotkey(), "default hotkey registration")
    print("CasprFlow checks passed")
    exit(0)
}

RunLoop.main.run()

import AppKit

public enum PhaseFivePointFiveSelfCheck {
    public static func menuStateTitlesReflectPermissions() -> Bool {
        StatusItemController.accessibilityMenuTitle(isGranted: true) == "Accessibility: Granted"
            && StatusItemController.accessibilityMenuTitle(isGranted: false) == "Enable Accessibility..."
            && StatusItemController.screenRecordingMenuTitle(isGranted: true) == "Screen Recording: Granted"
            && StatusItemController.screenRecordingMenuTitle(isGranted: false) == "Enable Screen Recording..."
    }

    public static func permissionPanelsMapToSettingsPanes() -> Bool {
        PermissionGuidePanel.accessibility.settingsPaneIdentifier == "Privacy_Accessibility"
            && PermissionGuidePanel.screenRecording.settingsPaneIdentifier == "Privacy_ScreenCapture"
    }

    public static func dragSourceExposesBundleFileURL() -> Bool {
        let bundleURL = URL(fileURLWithPath: "/Applications/CasprFlow.app")
        return PermissionDragSourceView
            .pasteboardTypes(for: bundleURL)
            .contains(.fileURL)
    }
}

import CoreGraphics

@MainActor
final class ScreenRecordingPermissionService {
    var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func openSystemSettings() {
        PermissionGuidePanel.screenRecording.openSystemSettings()
    }
}

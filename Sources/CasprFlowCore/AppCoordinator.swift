import AppKit

/// Top-level wiring for the CasprFlow menu-bar app.
///
/// This is the post-pivot skeleton: it registers the global hotkey, owns the
/// permission + status-item plumbing, and owns the prewarmed voice HUD. The
/// route→dispatch loop is wired in on top of this shell.
@MainActor
final class AppCoordinator {
    private let hotkeyService = HotkeyService()
    private let permissionService = AccessibilityPermissionService()
    private let screenRecordingPermissionService = ScreenRecordingPermissionService()
    private let intentRouter: any IntentRouter = DeterministicRouter()
    private let handlerRegistry = HandlerRegistry(handlers: [
        BrowserSearchHandler(),
        OpenURLHandler(),
        OpenAppHandler(),
        ShellCommandHandler()
    ])
    private lazy var permissionGuideController = PermissionGuideController(
        accessibilityPermissionService: permissionService,
        screenRecordingPermissionService: screenRecordingPermissionService,
        onPermissionStateChanged: { [weak self] in
            self?.statusItemController?.refresh()
        }
    )

    private lazy var voiceHUDController = VoiceHUDController { [weak self] transcript in
        guard let self else {
            return ActionResult(ok: false, message: "Voice input failed. Try again.")
        }

        return await self.routeAndDispatch(transcript)
    }
    private var statusItemController: StatusItemController?
    private var isEnabled = true

    func start() {
        statusItemController = StatusItemController(
            onToggleEnabled: { [weak self] in self?.toggleEnabled() },
            onRequestAccessibility: { [weak self] in self?.showPermissionGuide(.accessibility) },
            onRequestScreenRecording: { [weak self] in self?.showPermissionGuide(.screenRecording) },
            onQuit: { NSApp.terminate(nil) },
            stateProvider: { [weak self] in
                StatusItemState(
                    isEnabled: self?.isEnabled ?? false,
                    isAccessibilityTrusted: self?.permissionService.isTrusted ?? false,
                    isScreenRecordingGranted: self?.screenRecordingPermissionService.isGranted ?? false
                )
            }
        )
        NSLog("[CasprFlow] Status item initialized")

        // Point first-run setup at the exact permission pane.
        if !permissionService.isTrusted {
            permissionGuideController.present(panel: .accessibility)
        }

        registerHotkey()
    }

    func stop() {
        hotkeyService.unregister()
        permissionGuideController.dismiss()
    }

    private func registerHotkey() {
        do {
            // Push-to-talk: hold = listen, release = process.
            try hotkeyService.registerDefaultHotkey(
                onPress: { [weak self] in self?.startListening() },
                onRelease: { [weak self] in self?.stopListening() }
            )
            NSLog("[CasprFlow] Hotkey registered: %@", HotkeyDescriptor.defaultHotkey.displayName)
        } catch {
            NSLog("[CasprFlow] Hotkey registration failed: %@", String(describing: error))
        }
    }

    private func toggleEnabled() {
        isEnabled.toggle()
        statusItemController?.refresh()
        if !isEnabled { voiceHUDController.dismiss() }
    }

    /// Hotkey pressed: show the center-bottom transcript HUD and begin on-device capture.
    private func startListening() {
        guard isEnabled else { return }
        NSLog("[CasprFlow] Push-to-talk press")
        voiceHUDController.beginListening()
    }

    /// Hotkey released: show the spinner immediately and log the finalized transcript.
    private func stopListening() {
        guard isEnabled else { return }
        NSLog("[CasprFlow] Push-to-talk release")
        voiceHUDController.endListening()
    }

    private func routeAndDispatch(_ transcript: String) async -> ActionResult {
        let submitTime = DispatchTime.now()
        let loggedTranscript = transcript.isEmpty ? "<empty>" : transcript
        NSLog("[CasprFlow] Voice transcript: %@", loggedTranscript)

        let intent = await intentRouter.route(transcript)
        let routeDoneTime = DispatchTime.now()
        NSLog(
            "[CasprFlow] Routed intent: kind=%@ confidence=%.2f slots=%@",
            intent.kind.rawValue,
            intent.confidence,
            String(describing: intent.slots)
        )

        guard intent.kind != .unknown else {
            return ActionResult(ok: false, message: "Didn't catch that.")
        }

        let result = await handlerRegistry.dispatch(intent)
        let dispatchDoneTime = DispatchTime.now()
        NSLog(
            "[CasprFlow] Dispatch result: ok=%@ message=%@",
            result.ok ? "true" : "false",
            result.message ?? ""
        )
        NSLog(
            "[CasprFlow] Dispatch latency: route=%.2fms dispatch=%.2fms total=%.2fms",
            Self.milliseconds(from: submitTime, to: routeDoneTime),
            Self.milliseconds(from: routeDoneTime, to: dispatchDoneTime),
            Self.milliseconds(from: submitTime, to: dispatchDoneTime)
        )
        return result
    }

    private func showPermissionGuide(_ panel: PermissionGuidePanel) {
        permissionGuideController.present(panel: panel)
        statusItemController?.refresh()
    }

    private static func milliseconds(from start: DispatchTime, to end: DispatchTime) -> Double {
        Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    }
}

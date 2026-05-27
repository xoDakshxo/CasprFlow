import AppKit
import SwiftUI

@MainActor
public final class VoiceHUDController {
    private let panel: FloatingPanel
    private let model = VoiceHUDModel()
    private let voiceInputService: VoiceInputService
    private let onTranscript: (String) -> Void

    private var isHolding = false
    private var captureTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var errorDismissTask: Task<Void, Never>?

    public init(onTranscript: @escaping (String) -> Void) {
        self.onTranscript = onTranscript
        self.voiceInputService = VoiceInputService()

        let size = NSSize(width: 320, height: 56)
        self.panel = FloatingPanel.make(size: size)
        let hostingView = NSHostingView(rootView: VoiceHUDView(model: model))
        hostingView.frame = NSRect(origin: .zero, size: size)
        self.panel.contentView = hostingView
        self.panel.onEscape = { [weak self] in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    public func beginListening() {
        guard !isHolding else { return }

        isHolding = true
        stopTask?.cancel()
        stopTask = nil
        errorDismissTask?.cancel()
        errorDismissTask = nil

        model.partialTranscript = ""
        setState(.listening)
        panel.positionCenterBottom()
        panel.orderFrontRegardless()

        captureTask?.cancel()
        captureTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await voiceInputService.requestPermissionsIfNeeded()
                guard isHolding else { return }

                try voiceInputService.start(
                    onPartial: { [weak self] partial in
                        guard let self, self.isHolding else { return }
                        self.model.partialTranscript = partial
                    },
                    onLevel: { _ in
                        // Level is still collected for future UI, but the HUD now shows text.
                    }
                )
            } catch {
                self.isHolding = false
                self.voiceInputService.cancel()
                self.fail(Self.message(for: error))
            }
        }
    }

    public func endListening() {
        guard isHolding else { return }

        isHolding = false
        captureTask?.cancel()
        captureTask = nil

        setState(.processing)
        panel.positionCenterBottom()
        panel.orderFrontRegardless()

        stopTask?.cancel()
        stopTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let transcript = await voiceInputService.stop()
            guard !Task.isCancelled else { return }
            onTranscript(transcript)

            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            self.dismiss()
        }
    }

    public func fail(_ message: String) {
        setState(.error(message: message))
        panel.positionCenterBottom()
        panel.orderFrontRegardless()

        errorDismissTask?.cancel()
        errorDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    public func dismiss() {
        captureTask?.cancel()
        stopTask?.cancel()
        errorDismissTask?.cancel()
        captureTask = nil
        stopTask = nil
        errorDismissTask = nil
        isHolding = false
        voiceInputService.cancel()
        model.partialTranscript = ""
        setState(.idle)
        panel.orderOut(nil)
    }

    private func setState(_ state: VoiceHUDState) {
        model.state = state
    }

    private static func message(for error: Error) -> String {
        if let voiceError = error as? VoiceInputError {
            return voiceError.userMessage
        }
        return "Voice input failed. Try again."
    }
}

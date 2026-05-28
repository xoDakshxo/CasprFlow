import AVFAudio
import AVFoundation
import Foundation
import Speech

public enum VoiceInputError: Error, Equatable, Sendable {
    case microphonePermissionNeeded
    case microphonePermissionDenied
    case speechPermissionNeeded
    case speechPermissionDenied
    case speechPermissionRestricted
    case recognizerUnavailable
    case audioInputUnavailable
    case audioEngineStartFailed(String)

    public var userMessage: String {
        switch self {
        case .microphonePermissionNeeded:
            return "Approve Microphone, then hold again."
        case .microphonePermissionDenied:
            return "Enable Microphone in System Settings."
        case .speechPermissionNeeded:
            return "Approve Speech Recognition, then hold again."
        case .speechPermissionDenied:
            return "Enable Speech Recognition in System Settings."
        case .speechPermissionRestricted:
            return "Speech Recognition is restricted."
        case .recognizerUnavailable:
            return "On-device speech is unavailable."
        case .audioInputUnavailable:
            return "No microphone input available."
        case .audioEngineStartFailed:
            return "Could not start microphone capture."
        }
    }
}

public enum VoiceLevelMeter {
    private static let noiseFloor: Float = 0.012
    private static let speechCeiling: Float = 0.22

    public static func normalizedRMS(_ rms: Float) -> Float {
        guard rms.isFinite, rms > noiseFloor else { return 0 }

        let scaled = (rms - noiseFloor) / (speechCeiling - noiseFloor)
        return min(max(pow(scaled, 0.6), 0), 1)
    }

    static func level(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else { return 0 }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return 0 }

        var sumSquares: Float = 0
        for channelIndex in 0..<channelCount {
            let samples = channels[channelIndex]
            for frameIndex in 0..<frameCount {
                let sample = samples[frameIndex]
                sumSquares += sample * sample
            }
        }

        let meanSquare = sumSquares / Float(frameCount * channelCount)
        return normalizedRMS(sqrt(meanSquare))
    }
}

public enum VoiceCaptureFinalization {
    public static let speechLevelThreshold: Float = 0.08
    public static let transcriptReadyTimeoutNanoseconds: UInt64 = 800_000_000
    public static let speechDetectedTimeoutNanoseconds: UInt64 = 1_800_000_000
    public static let silenceTimeoutNanoseconds: UInt64 = 350_000_000

    public static func heardSpeech(fromLevel level: Float) -> Bool {
        level >= speechLevelThreshold
    }

    public static func timeoutNanoseconds(hasTranscript: Bool, heardSpeech: Bool) -> UInt64 {
        if hasTranscript {
            return transcriptReadyTimeoutNanoseconds
        }

        if heardSpeech {
            return speechDetectedTimeoutNanoseconds
        }

        return silenceTimeoutNanoseconds
    }

    public static func timeoutNanoseconds(transcript: String?, heardSpeech: Bool) -> UInt64 {
        guard let cleanedTranscript = SelectionTextNormalizer.clean(transcript) else {
            return timeoutNanoseconds(hasTranscript: false, heardSpeech: heardSpeech)
        }

        let wordCount = cleanedTranscript.split(whereSeparator: { $0.isWhitespace }).count
        if wordCount <= 1, heardSpeech {
            return speechDetectedTimeoutNanoseconds
        }

        return transcriptReadyTimeoutNanoseconds
    }

    public static func shouldFinishOnRecognitionError(hasTranscript: Bool, heardSpeech: Bool) -> Bool {
        hasTranscript || !heardSpeech
    }
}

public struct VoiceRecognitionConfiguration: Equatable, Sendable {
    public let localeIdentifier: String
    public let contextualStrings: [String]

    public init(
        localeIdentifier: String = "en_US",
        contextualStrings: [String] = Self.defaultContextualStrings
    ) {
        self.localeIdentifier = localeIdentifier
        self.contextualStrings = contextualStrings
    }

    public static let defaultContextualStrings: [String] = []

    public static func normalizedContextualStrings(_ strings: [String]) -> [String] {
        var seen = Set<String>()
        return strings.compactMap { value in
            guard let cleaned = SelectionTextNormalizer.clean(value) else { return nil }
            let key = DeterministicRouter.normalize(cleaned)
            guard seen.insert(key).inserted else { return nil }
            return cleaned
        }
    }
}

@MainActor
public final class VoiceInputService {
    private let audioEngine = AVAudioEngine()
    private let configuration: VoiceRecognitionConfiguration
    private let speechRecognizer: SFSpeechRecognizer?

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var stopContinuation: CheckedContinuation<String, Never>?
    private var isCapturing = false
    private var heardSpeech = false

    public init(configuration: VoiceRecognitionConfiguration = VoiceRecognitionConfiguration()) {
        self.configuration = configuration
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: configuration.localeIdentifier))
    }

    public func requestPermissionsIfNeeded() async throws {
        async let speechStatus = requestSpeechAuthorizationIfNeeded()
        async let microphoneGranted = requestMicrophoneAuthorizationIfNeeded()

        let resolvedSpeechStatus = await speechStatus
        let resolvedMicrophoneGranted = await microphoneGranted

        switch resolvedSpeechStatus {
        case .authorized:
            break
        case .notDetermined:
            throw VoiceInputError.speechPermissionNeeded
        case .denied:
            throw VoiceInputError.speechPermissionDenied
        case .restricted:
            throw VoiceInputError.speechPermissionRestricted
        @unknown default:
            throw VoiceInputError.speechPermissionDenied
        }

        guard resolvedMicrophoneGranted else {
            throw VoiceInputError.microphonePermissionDenied
        }
    }

    public func start(
        onPartial: @escaping @MainActor (String) -> Void,
        onLevel: @escaping @MainActor (Float) -> Void
    ) throws {
        if isCapturing {
            return
        }

        try ensureAuthorizedForImmediateStart()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceInputError.recognizerUnavailable
        }
        guard speechRecognizer.supportsOnDeviceRecognition else {
            throw VoiceInputError.recognizerUnavailable
        }

        guard AVCaptureDevice.default(for: .audio) != nil else {
            throw VoiceInputError.audioInputUnavailable
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw VoiceInputError.audioInputUnavailable
        }

        finishStopIfNeeded()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        latestTranscript = ""
        heardSpeech = false

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        request.contextualStrings = VoiceRecognitionConfiguration.normalizedContextualStrings(
            configuration.contextualStrings
        )
        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(
            with: request,
            resultHandler: Self.makeRecognitionHandler(
                onTranscript: { [weak self] transcript, isFinal in
                    guard let self else { return }
                    self.latestTranscript = transcript
                    onPartial(transcript)

                    if isFinal {
                        self.finishStopIfNeeded()
                    }
                },
                onError: { [weak self] in
                    self?.finishAfterRecognitionError()
                }
            )
        )

        let tap = Self.makeAudioTap(
            request: request,
            onLevel: { [weak self] level in
                if VoiceCaptureFinalization.heardSpeech(fromLevel: level) {
                    self?.heardSpeech = true
                }
                onLevel(level)
            }
        )

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat, block: tap)

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isCapturing = true
        } catch {
            removeInputTapIfAvailable()
            request.endAudio()
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            throw VoiceInputError.audioEngineStartFailed(error.localizedDescription)
        }
    }

    public func stop() async -> String {
        guard isCapturing else {
            return SelectionTextNormalizer.clean(latestTranscript) ?? ""
        }

        isCapturing = false
        removeInputTapIfAvailable()
        audioEngine.stop()
        recognitionRequest?.endAudio()

        return await withCheckedContinuation { continuation in
            if let pendingContinuation = stopContinuation {
                stopContinuation = nil
                let transcript = SelectionTextNormalizer.clean(latestTranscript) ?? ""
                pendingContinuation.resume(returning: transcript)
            }

            stopContinuation = continuation
            let timeout = VoiceCaptureFinalization.timeoutNanoseconds(
                transcript: latestTranscript,
                heardSpeech: heardSpeech
            )

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: timeout)
                self?.finishStopIfNeeded()
            }
        }
    }

    public func cancel() {
        isCapturing = false
        removeInputTapIfAvailable()
        audioEngine.stop()
        recognitionRequest?.endAudio()
        finishStopIfNeeded()
    }

    private func ensureAuthorizedForImmediateStart() throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            throw VoiceInputError.speechPermissionNeeded
        case .denied:
            throw VoiceInputError.speechPermissionDenied
        case .restricted:
            throw VoiceInputError.speechPermissionRestricted
        @unknown default:
            throw VoiceInputError.speechPermissionDenied
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            throw VoiceInputError.microphonePermissionNeeded
        case .denied, .restricted:
            throw VoiceInputError.microphonePermissionDenied
        @unknown default:
            throw VoiceInputError.microphonePermissionDenied
        }
    }

    private nonisolated func requestSpeechAuthorizationIfNeeded() async -> SFSpeechRecognizerAuthorizationStatus {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .notDetermined else { return status }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private nonisolated func requestMicrophoneAuthorizationIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private nonisolated static func makeRecognitionHandler(
        onTranscript: @escaping @MainActor (String, Bool) -> Void,
        onError: @escaping @MainActor () -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false

            Task { @MainActor in
                if let transcript {
                    onTranscript(transcript, isFinal)
                }

                if error != nil {
                    onError()
                }
            }
        }
    }

    private nonisolated static func makeAudioTap(
        request: SFSpeechAudioBufferRecognitionRequest,
        onLevel: @escaping @MainActor (Float) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            let level = VoiceLevelMeter.level(from: buffer)

            Task { @MainActor in
                onLevel(level)
            }
        }
    }

    private func finishStopIfNeeded() {
        finishStopIfNeeded(allowEmpty: true)
    }

    private func finishAfterRecognitionError() {
        let hasTranscript = SelectionTextNormalizer.clean(latestTranscript) != nil
        let allowEmpty = VoiceCaptureFinalization.shouldFinishOnRecognitionError(
            hasTranscript: hasTranscript,
            heardSpeech: heardSpeech
        )

        finishStopIfNeeded(allowEmpty: allowEmpty)
    }

    private func finishStopIfNeeded(allowEmpty: Bool) {
        guard let continuation = stopContinuation else { return }

        let transcript = SelectionTextNormalizer.clean(latestTranscript) ?? ""
        guard allowEmpty || !transcript.isEmpty else { return }

        stopContinuation = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        continuation.resume(returning: transcript)
    }

    private func removeInputTapIfAvailable() {
        guard AVCaptureDevice.default(for: .audio) != nil else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

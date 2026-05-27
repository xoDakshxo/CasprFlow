import SwiftUI

public enum VoiceHUDState: Equatable, Sendable {
    case idle
    case listening
    case processing
    case result(message: String)
    case error(message: String)

    var isProcessing: Bool {
        if case .processing = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }

    var resultMessage: String? {
        if case .result(let message) = self {
            return message
        }
        return nil
    }
}

struct VoiceHUDView: View {
    @ObservedObject var model: VoiceHUDModel

    var body: some View {
        ZStack {
            if let errorMessage = model.state.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.yellow)

                    Text(errorMessage)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: 214, alignment: .leading)
                }
                .padding(.horizontal, 14)
            } else if let resultMessage = model.state.resultMessage {
                resultReadout(resultMessage)
            } else if model.state.isProcessing {
                processingReadout
            } else {
                transcriptReadout
            }
        }
        .frame(width: 320, height: 56)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: model.state)
        .animation(.easeOut(duration: 0.08), value: model.partialTranscript)
        .accessibilityElement(children: .combine)
    }

    private var transcriptReadout: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating, value: model.isListening)

            Text(readoutText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(readoutIsPlaceholder ? .secondary : .primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if model.isListening {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
    }

    private var processingReadout: some View {
        let hasTranscript = model.hasTranscript

        return HStack(spacing: 8) {
            CasprFlowLoadingLogoMark(size: hasTranscript ? 16 : 22)

            if hasTranscript {
                Text(readoutText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
        }
        .padding(.horizontal, hasTranscript ? 16 : 0)
    }

    private func resultReadout(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.green)

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .foregroundStyle(.primary)
                .frame(maxWidth: 230, alignment: .leading)
        }
        .padding(.horizontal, 14)
    }

    private var readoutText: String {
        if let cleaned = SelectionTextNormalizer.clean(model.partialTranscript) {
            return cleaned
        }
        return "Listening..."
    }

    private var readoutIsPlaceholder: Bool {
        SelectionTextNormalizer.clean(model.partialTranscript) == nil
    }
}

@MainActor
final class VoiceHUDModel: ObservableObject {
    @Published var state: VoiceHUDState = .idle
    @Published var partialTranscript = ""

    var isListening: Bool {
        if case .listening = state {
            return true
        }
        return false
    }

    var hasTranscript: Bool {
        SelectionTextNormalizer.clean(partialTranscript) != nil
    }
}

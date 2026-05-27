import SwiftUI

public enum VoiceHUDState: Equatable, Sendable {
    case idle
    case listening
    case processing
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
            } else {
                transcriptReadout
                    .opacity(model.state.isProcessing ? 0 : 1)
                    .scaleEffect(model.state.isProcessing ? 0.96 : 1)
                    .blur(radius: model.state.isProcessing ? 3 : 0)

                CasprFlowLoadingLogoMark(size: 22)
                    .opacity(model.state.isProcessing ? 1 : 0)
                    .scaleEffect(model.state.isProcessing ? 1 : 0.48)
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
}

import CoreGraphics
import Foundation
@preconcurrency import Vision

/// In-process Apple Vision OCR for the current hotkey snapshot.
/// Adapted from the MIT-licensed bytefer/macos-vision-ocr request/output shape.
final class LocalOCRService {
    func recognizeText(in image: CGImage, source: String) -> [OCRTextCandidate] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.revision = VNRecognizeTextRequestRevision3
        request.minimumTextHeight = 0.01
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let observations = request.results else {
            return []
        }

        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first,
                  let text = SelectionTextNormalizer.clean(candidate.string) else {
                return nil
            }

            let box = observation.boundingBox
            return OCRTextCandidate(
                text: text,
                confidence: Double(candidate.confidence),
                boundingBox: NormalizedRect(
                    x: Double(box.origin.x),
                    y: Double(box.origin.y),
                    width: Double(box.width),
                    height: Double(box.height)
                ),
                source: source
            )
        }
        .sorted { lhs, rhs in
            let rowDelta = lhs.boundingBox.y - rhs.boundingBox.y
            if abs(rowDelta) > 0.01 {
                return lhs.boundingBox.y > rhs.boundingBox.y
            }
            return lhs.boundingBox.x < rhs.boundingBox.x
        }
    }

}

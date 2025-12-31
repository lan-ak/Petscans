import UIKit
import Vision

/// Service for extracting text from images using Apple's Vision framework
actor OCRService: OCRServiceProtocol {

    // MARK: - Error Types

    enum OCRError: LocalizedError {
        case noTextDetected
        case lowConfidence(Float)
        case imageTooSmall
        case processingFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .noTextDetected:
                return "No Text Detected"
            case .lowConfidence(let confidence):
                return "Low Confidence (\(Int(confidence * 100))%)"
            case .imageTooSmall:
                return "Image Too Small"
            case .processingFailed:
                return "Processing Failed"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .noTextDetected:
                return "No ingredients found in the image. Please ensure the ingredient list is clearly visible and try again."
            case .lowConfidence:
                return "The text quality may be too low. Try taking a clearer photo with better lighting."
            case .imageTooSmall:
                return "The image resolution is too low. Please take a photo closer to the label."
            case .processingFailed:
                return "An error occurred while analyzing the image. Please try again."
            }
        }
    }

    // MARK: - Configuration

    private let minimumConfidence: Float = 0.6
    private let minimumImageWidth: CGFloat = 800

    // MARK: - Public Methods

    func extractText(from image: UIImage) async throws -> OCRResult {
        // Validate image size
        guard image.size.width >= minimumImageWidth else {
            throw OCRError.imageTooSmall
        }

        guard let cgImage = image.cgImage else {
            throw OCRError.processingFailed(underlying: NSError(
                domain: "OCRService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"]
            ))
        }

        // Create Vision request
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true

        // Perform request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw OCRError.processingFailed(underlying: error)
        }

        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextDetected
        }

        // Combine recognized text
        let (text, averageConfidence) = combineRecognizedText(observations)

        // Validate we got meaningful text
        guard !text.isEmpty else {
            throw OCRError.noTextDetected
        }

        // Check confidence threshold
        if averageConfidence < minimumConfidence {
            throw OCRError.lowConfidence(averageConfidence)
        }

        // Post-process the text
        let processedText = postProcessText(text)

        // Validate processed text looks like ingredients
        guard validateIngredientText(processedText) else {
            throw OCRError.noTextDetected
        }

        return OCRResult(text: processedText, confidence: averageConfidence)
    }

    // MARK: - Private Methods

    private func combineRecognizedText(_ observations: [VNRecognizedTextObservation]) -> (text: String, confidence: Float) {
        var allText: [String] = []
        var confidences: [Float] = []

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            allText.append(topCandidate.string)
            confidences.append(topCandidate.confidence)
        }

        let combinedText = allText.joined(separator: " ")
        let averageConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)

        return (combinedText, averageConfidence)
    }

    private func postProcessText(_ text: String) -> String {
        var processed = text

        // Normalize whitespace
        processed = processed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Replace smart quotes with regular quotes (Unicode U+201C, U+201D, U+2018, U+2019)
        processed = processed.replacingOccurrences(of: "\u{201C}", with: "\"")
        processed = processed.replacingOccurrences(of: "\u{201D}", with: "\"")
        processed = processed.replacingOccurrences(of: "\u{2018}", with: "'")
        processed = processed.replacingOccurrences(of: "\u{2019}", with: "'")

        // Common OCR corrections for ingredients
        // "l" vs "I" in context
        processed = processed.replacingOccurrences(of: " l ", with: " I ")

        // Ensure comma separation (Vision might miss some commas)
        // This is a heuristic - if we have long text without commas, it might be wrong
        // But we'll let the ingredient matcher handle it

        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validateIngredientText(_ text: String) -> Bool {
        // Check minimum length
        guard text.count >= 10 else { return false }

        // Check for at least some alphabetic content
        let alphaCount = text.filter { $0.isLetter }.count
        let alphaRatio = Float(alphaCount) / Float(max(1, text.count))
        guard alphaRatio > 0.5 else { return false }

        // Check for potential ingredient separators (comma, semicolon, or multiple words)
        let hasSeparators = text.contains(",") || text.contains(";")
        let wordCount = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count

        return hasSeparators || wordCount >= 3
    }
}

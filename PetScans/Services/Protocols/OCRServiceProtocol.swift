import UIKit

/// Result from OCR text extraction
struct OCRResult: Sendable {
    let text: String
    let confidence: Float  // 0.0 to 1.0
}

/// Protocol for OCR text extraction service
protocol OCRServiceProtocol: Sendable {
    /// Extracts text from an image
    /// - Parameter image: The image to extract text from
    /// - Returns: OCR result with extracted text and confidence score
    /// - Throws: OCRError if extraction fails
    func extractText(from image: UIImage) async throws -> OCRResult
}

import Foundation
import UIKit

/// Actor-based service for identifying pet food products from packaging images
/// Uses OpenAI GPT-4o Vision API to extract brand and product name
actor ProductVisionService: ProductVisionServiceProtocol {

    // MARK: - Properties

    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let session: URLSession

    // MARK: - Init

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public Methods

    /// Identify a pet food product from a packaging photo
    func identifyProduct(from image: UIImage) async throws -> ProductIdentification {
        // Encode image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ProductVisionError.imageEncodingFailed
        }
        let base64Image = imageData.base64EncodedString()

        print("DEBUG: ProductVision - Image encoded, size: \(imageData.count) bytes")

        // Build request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let requestBody = ChatCompletionRequest(
            model: "gpt-4o",
            messages: [
                Message(
                    role: "user",
                    content: [
                        ContentPart(type: "text", text: extractionPrompt, imageURL: nil),
                        ContentPart(
                            type: "image_url",
                            text: nil,
                            imageURL: ImageURL(url: "data:image/jpeg;base64,\(base64Image)")
                        )
                    ]
                )
            ],
            maxTokens: 500,
            responseFormat: ResponseFormat(type: "json_object")
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw ProductVisionError.decodingError(underlying: error)
        }

        print("DEBUG: ProductVision - Sending request to OpenAI")

        // Execute request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("DEBUG: ProductVision - Network error: \(error)")
            throw ProductVisionError.networkError(underlying: error)
        }

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProductVisionError.networkError(underlying: URLError(.badServerResponse))
        }

        print("DEBUG: ProductVision - HTTP status: \(httpResponse.statusCode)")

        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("DEBUG: ProductVision - Response: \(responseString.prefix(500))...")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw ProductVisionError.invalidAPIKey
        case 429:
            throw ProductVisionError.rateLimited
        case 400..<500:
            throw ProductVisionError.invalidResponse
        default:
            throw ProductVisionError.networkError(underlying: URLError(.badServerResponse))
        }

        // Decode OpenAI response
        let apiResponse: ChatCompletionResponse
        do {
            apiResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            print("DEBUG: ProductVision - Decoding error: \(error)")
            throw ProductVisionError.decodingError(underlying: error)
        }

        // Extract content from response
        guard let content = apiResponse.choices.first?.message.content else {
            throw ProductVisionError.invalidResponse
        }

        print("DEBUG: ProductVision - Raw content: \(content)")

        // Parse JSON content into ProductIdentification
        guard let contentData = content.data(using: .utf8) else {
            throw ProductVisionError.invalidResponse
        }

        let identification: ProductIdentification
        do {
            identification = try JSONDecoder().decode(ProductIdentification.self, from: contentData)
        } catch {
            print("DEBUG: ProductVision - Failed to parse identification: \(error)")
            throw ProductVisionError.decodingError(underlying: error)
        }

        print("DEBUG: ProductVision - Identified: \(identification.brand ?? "nil") - \(identification.productName ?? "nil") | Protein: \(identification.primaryProtein ?? "nil"), Carb: \(identification.primaryCarb ?? "nil") (confidence: \(identification.confidence))")

        // Validate we got usable data
        guard identification.searchQuery != nil else {
            throw ProductVisionError.noProductFound
        }

        return identification
    }

    // MARK: - Private

    private var extractionPrompt: String {
        """
        Analyze this pet food product packaging image.

        Extract the following information:
        - brand: The brand name (e.g., "Blue Buffalo", "Purina", "Royal Canin", "Hill's Science Diet")
        - productName: The full product name or line (e.g., "Wilderness Chicken Recipe", "Pro Plan Adult")
        - species: The target animal - must be "dog", "cat", or "unknown"
        - primaryProtein: The main protein source visible on packaging (e.g., "Chicken", "Salmon", "Beef", "Turkey")
        - primaryCarb: The main carbohydrate source if visible (e.g., "Rice", "Sweet Potato", "Oatmeal") or "Grain-Free" if indicated
        - confidence: Your confidence level from 0.0 to 1.0

        Important guidelines:
        - Look for brand logos, product line names, and descriptive text on the packaging
        - If multiple products are visible, focus on the most prominent one
        - Return null for fields you cannot determine with reasonable certainty
        - Only return confidence > 0.7 if brand AND product name are clearly visible
        - For protein/carb, look at flavor descriptions, product names, and any visible ingredient highlights

        Respond ONLY with valid JSON in this exact format:
        {
            "brand": "Brand Name",
            "productName": "Product Name",
            "species": "dog",
            "primaryProtein": "Chicken",
            "primaryCarb": "Rice",
            "confidence": 0.85
        }
        """
    }
}

// MARK: - Request Models

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

private struct Message: Encodable {
    let role: String
    let content: [ContentPart]
}

private struct ContentPart: Encodable {
    let type: String
    let text: String?
    let imageURL: ImageURL?

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }
}

private struct ImageURL: Encodable {
    let url: String
}

private struct ResponseFormat: Encodable {
    let type: String
}

// MARK: - Response Models

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]
}

private struct Choice: Decodable {
    let message: ResponseMessage
}

private struct ResponseMessage: Decodable {
    let content: String?
}

import Foundation

/// Actor-based service for scraping pet food product data via Firecrawl API
/// Uses AI-powered extraction to reliably get ingredients from any retailer
actor FirecrawlService: FirecrawlServiceProtocol {

    // MARK: - Properties

    private let apiKey: String
    private let baseURL = "https://api.firecrawl.dev/v1"
    private let session: URLSession

    // MARK: - Init

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public Methods

    /// Scrape product details from any pet food retailer URL
    func scrapeProduct(url: URL) async throws -> FirecrawlProduct {
        let requestURL = URL(string: "\(baseURL)/scrape")!

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Firecrawl can take time to render JS

        // Build request body with extraction schema
        let requestBody = ScrapeRequest(
            url: url.absoluteString,
            formats: ["extract"],
            extract: ExtractConfig(
                prompt: """
                Extract the pet food product details from this page.
                - name: The full product name
                - brand: The brand name (e.g., Friskies, Blue Buffalo, Royal Canin)
                - ingredients: The complete ingredients list, split into individual items
                - price: The current price as a number
                - imageURL: The main product image URL
                """,
                schema: extractionSchema
            )
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw FirecrawlError.decodingError(underlying: error)
        }

        print("DEBUG: Firecrawl scraping URL: \(url.absoluteString)")

        // Execute request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("DEBUG: Firecrawl network error: \(error)")
            throw FirecrawlError.networkError(underlying: error)
        }

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirecrawlError.networkError(underlying: URLError(.badServerResponse))
        }

        print("DEBUG: Firecrawl HTTP status: \(httpResponse.statusCode)")

        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("DEBUG: Firecrawl response: \(responseString.prefix(500))...")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw FirecrawlError.invalidAPIKey
        case 429:
            throw FirecrawlError.rateLimited
        case 400..<500:
            // Try to extract error message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw FirecrawlError.scrapeFailed(message: errorResponse.error ?? "Unknown error")
            }
            throw FirecrawlError.scrapeFailed(message: "Request failed with status \(httpResponse.statusCode)")
        default:
            throw FirecrawlError.networkError(underlying: URLError(.badServerResponse))
        }

        // Decode response
        let apiResponse: ScrapeResponse
        do {
            apiResponse = try JSONDecoder().decode(ScrapeResponse.self, from: data)
        } catch {
            print("DEBUG: Firecrawl decoding error: \(error)")
            throw FirecrawlError.decodingError(underlying: error)
        }

        // Check for successful extraction
        guard apiResponse.success,
              let extractedData = apiResponse.data?.extract else {
            throw FirecrawlError.extractionFailed
        }

        // Validate we got ingredients
        guard !extractedData.ingredients.isEmpty else {
            throw FirecrawlError.extractionFailed
        }

        print("DEBUG: Firecrawl extracted product: \(extractedData.name), ingredients: \(extractedData.ingredients.count)")

        return FirecrawlProduct(
            name: extractedData.name,
            brand: extractedData.brand,
            ingredients: extractedData.ingredients,
            price: extractedData.price,
            imageURL: extractedData.imageURL.flatMap { URL(string: $0) }
        )
    }

    // MARK: - Private

    /// JSON Schema for extraction
    private var extractionSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "Full product name"],
                "brand": ["type": "string", "description": "Brand name"],
                "ingredients": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "List of ingredients, each as a separate string"
                ],
                "price": ["type": "number", "description": "Current price"],
                "imageURL": ["type": "string", "description": "Main product image URL"]
            ],
            "required": ["name", "ingredients"]
        ]
    }
}

// MARK: - Request/Response Models

private struct ScrapeRequest: Encodable {
    let url: String
    let formats: [String]
    let extract: ExtractConfig
}

private struct ExtractConfig: Encodable {
    let prompt: String
    let schema: [String: Any]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prompt, forKey: .prompt)
        // Encode schema as JSON data then as a nested container
        let schemaData = try JSONSerialization.data(withJSONObject: schema)
        let schemaJSON = try JSONSerialization.jsonObject(with: schemaData)
        try container.encode(AnyCodable(schemaJSON), forKey: .schema)
    }

    private enum CodingKeys: String, CodingKey {
        case prompt, schema
    }
}

private struct ScrapeResponse: Decodable {
    let success: Bool
    let data: ScrapeData?
}

private struct ScrapeData: Decodable {
    let extract: ExtractedProduct?
}

private struct ExtractedProduct: Decodable {
    let name: String
    let brand: String?
    let ingredients: [String]
    let price: Double?
    let imageURL: String?
}

private struct ErrorResponse: Decodable {
    let success: Bool
    let error: String?
}

// MARK: - AnyCodable Helper

/// Helper to encode arbitrary JSON values
private struct AnyCodable: Encodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

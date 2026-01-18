import Foundation

/// Actor-based service for scraping pet food product data via Firecrawl API
/// Uses AI-powered extraction to reliably get ingredients from any retailer
actor FirecrawlService: FirecrawlServiceProtocol {

    // MARK: - Properties

    private let apiKey: String
    private let baseURL = "https://api.firecrawl.dev"
    private let session: URLSession

    // Polling configuration for Agent API
    private let pollingInterval: TimeInterval = 2.0  // seconds
    private let maxPollingAttempts: Int = 45         // 45 * 2s = 90s max
    private let jobTimeout: TimeInterval = 90.0      // Overall timeout

    // MARK: - Init

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public Methods

    /// Scrape product details from any pet food retailer URL
    func scrapeProduct(url: URL) async throws -> FirecrawlProduct {
        let requestURL = URL(string: "\(baseURL)/v1/scrape")!

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

    /// Search for and extract pet food product data using Agent API
    /// The Agent API intelligently searches the web and extracts structured data
    func searchAndExtractProduct(config: AgentSearchConfig) async throws -> AgentSearchResult {
        // Step 1: Start the agent job
        let jobId = try await startAgentJob(config: config)
        print("DEBUG: Agent job started with ID: \(jobId)")

        // Step 2: Poll for completion
        let result = try await pollForCompletion(jobId: jobId)
        print("DEBUG: Agent job completed, credits used: \(result.creditsUsed)")

        return result
    }

    // MARK: - Private Agent API Methods

    private func startAgentJob(config: AgentSearchConfig) async throws -> String {
        let requestURL = URL(string: "\(baseURL)/v2/agent")!

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Build prompt - must be explicit about EXTRACTING data, not just finding pages
        let brandPart = config.brand.map { " by \($0)" } ?? ""
        let prompt = """
            Search the web for "\(config.productName)"\(brandPart) pet food and EXTRACT the complete ingredients list from the product page.

            IMPORTANT: You must navigate to the product page and extract the actual ingredient text from the page content. Do not just find the page - read and return the ingredients.

            Search these sources in order:
            1. Manufacturer websites (purina.com, hillspet.com, royalcanin.com, bluebuffalo.com, etc.)
            2. Pet retailers (chewy.com, petco.com, petsmart.com, amazon.com)

            From the product page, extract and return:
            - name: The exact product name as shown on the page
            - brand: The brand name
            - ingredients: The COMPLETE ingredients list - split each ingredient into a separate array item. This is required.
            - price: Current price if visible
            - imageURL: Main product image URL

            The ingredients field is REQUIRED - if you cannot find ingredients, the extraction has failed.
            """

        let requestBody = AgentStartRequest(
            prompt: prompt,
            schema: agentExtractionSchema,
            maxCredits: config.maxCredits,
            model: config.model.rawValue
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw FirecrawlError.decodingError(underlying: error)
        }

        print("DEBUG: Starting Agent job for: \(config.productName)")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("DEBUG: Agent start network error: \(error)")
            throw FirecrawlError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirecrawlError.networkError(underlying: URLError(.badServerResponse))
        }

        print("DEBUG: Agent start HTTP status: \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("DEBUG: Agent start response: \(responseString.prefix(500))...")
        }

        switch httpResponse.statusCode {
        case 200, 201:
            let startResponse = try JSONDecoder().decode(AgentStartResponse.self, from: data)
            guard startResponse.success, let jobId = startResponse.id else {
                throw FirecrawlError.agentJobFailed(message: "Failed to start agent job")
            }
            return jobId
        case 401, 403:
            throw FirecrawlError.invalidAPIKey
        case 402:
            throw FirecrawlError.insufficientCredits
        case 429:
            throw FirecrawlError.rateLimited
        default:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw FirecrawlError.agentJobFailed(message: errorResponse.error ?? "Unknown error")
            }
            throw FirecrawlError.networkError(underlying: URLError(.badServerResponse))
        }
    }

    private func pollForCompletion(jobId: String) async throws -> AgentSearchResult {
        let startTime = Date()
        var attempts = 0

        while attempts < maxPollingAttempts {
            // Check timeout
            if Date().timeIntervalSince(startTime) > jobTimeout {
                throw FirecrawlError.agentJobTimeout
            }

            // Wait before polling (except first attempt)
            if attempts > 0 {
                try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
            }
            attempts += 1

            // Poll for status
            let status = try await getAgentStatus(jobId: jobId)

            switch status.status {
            case .processing:
                print("DEBUG: Agent job still processing (attempt \(attempts)/\(maxPollingAttempts))")
                continue

            case .completed:
                guard let extractedData = status.data else {
                    throw FirecrawlError.extractionFailed
                }

                // Validate we got ingredients
                guard !extractedData.ingredients.isEmpty else {
                    throw FirecrawlError.extractionFailed
                }

                let product = FirecrawlProduct(
                    name: extractedData.name,
                    brand: extractedData.brand,
                    ingredients: extractedData.ingredients,
                    price: extractedData.price,
                    imageURL: extractedData.imageURL.flatMap { URL(string: $0) }
                )

                return AgentSearchResult(
                    product: product,
                    creditsUsed: status.creditsUsed ?? 0,
                    source: nil
                )

            case .failed:
                throw FirecrawlError.agentJobFailed(message: status.error ?? "Unknown error")
            }
        }

        throw FirecrawlError.agentJobTimeout
    }

    private func getAgentStatus(jobId: String) async throws -> AgentStatusResponse {
        let requestURL = URL(string: "\(baseURL)/v2/agent/\(jobId)")!

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FirecrawlError.networkError(underlying: error)
        }

        // Debug: Print raw response to understand the structure
        if let responseString = String(data: data, encoding: .utf8) {
            print("DEBUG: Agent status raw response: \(responseString.prefix(1000))...")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirecrawlError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(AgentStatusResponse.self, from: data)
            } catch {
                print("DEBUG: Agent status decoding error: \(error)")
                throw FirecrawlError.decodingError(underlying: error)
            }
        case 401, 403:
            throw FirecrawlError.invalidAPIKey
        case 429:
            throw FirecrawlError.rateLimited
        default:
            throw FirecrawlError.networkError(underlying: URLError(.badServerResponse))
        }
    }

    // MARK: - Private

    /// JSON Schema for scrape extraction
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

    /// JSON Schema for Agent API extraction
    private var agentExtractionSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "Full product name as listed on the page"],
                "brand": ["type": "string", "description": "Brand name (e.g., Friskies, Blue Buffalo, Royal Canin)"],
                "ingredients": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Complete list of ingredients, each as a separate string"
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

// MARK: - Agent API Request/Response Models

private struct AgentStartRequest: Encodable {
    let prompt: String
    let schema: [String: Any]
    let maxCredits: Int
    let model: String

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(maxCredits, forKey: .maxCredits)
        try container.encode(model, forKey: .model)

        // Encode schema using AnyCodable helper
        let schemaData = try JSONSerialization.data(withJSONObject: schema)
        let schemaJSON = try JSONSerialization.jsonObject(with: schemaData)
        try container.encode(AnyCodable(schemaJSON), forKey: .schema)
    }

    private enum CodingKeys: String, CodingKey {
        case prompt, schema, maxCredits, model
    }
}

private struct AgentStartResponse: Decodable {
    let success: Bool
    let id: String?
}

private struct AgentStatusResponse: Decodable {
    let success: Bool
    let status: AgentJobStatus
    let data: AgentExtractedData?
    let error: String?
    let creditsUsed: Int?
}

private struct AgentExtractedData: Decodable {
    let name: String
    let brand: String?
    let ingredients: [String]
    let price: Double?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case ingredients
        case price
        case imageURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode name, default to empty string if missing
        self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
        self.brand = try? container.decode(String.self, forKey: .brand)

        // Ingredients is critical - default to empty array if missing
        if let ingredients = try? container.decode([String].self, forKey: .ingredients) {
            self.ingredients = ingredients
        } else {
            self.ingredients = []
        }

        self.price = try? container.decode(Double.self, forKey: .price)
        self.imageURL = try? container.decode(String.self, forKey: .imageURL)
    }
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

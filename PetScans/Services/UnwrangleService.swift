import Foundation

/// Actor-based service for fetching Chewy product data via Unwrangle API
/// Returns structured product data including ingredients (10 credits per request)
actor UnwrangleService: UnwrangleServiceProtocol {

    // MARK: - Properties

    private let apiKey: String
    private let baseURL = "https://data.unwrangle.com/api/getter/"
    private let session: URLSession

    // MARK: - Init

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public Methods

    /// Fetch product details including ingredients from a Chewy URL
    /// - Parameter url: The Chewy product URL
    /// - Returns: Product details including ingredients
    func fetchChewyProduct(url: URL) async throws -> UnwrangleProduct {
        // Percent-encode the Chewy URL as required by Unwrangle API
        // Use urlQueryAllowed but remove characters that need encoding in query values
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "&=")
        guard let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: allowedCharacters) else {
            print("DEBUG: Failed to encode URL: \(url.absoluteString)")
            throw UnwrangleError.networkError(underlying: URLError(.badURL))
        }

        // Build request URL manually to match the curl example format exactly
        let requestURLString = "\(baseURL)?platform=chewy_detail&url=\(encodedURL)&api_key=\(apiKey)"
        guard let requestURL = URL(string: requestURLString) else {
            print("DEBUG: Failed to create request URL from: \(requestURLString)")
            throw UnwrangleError.networkError(underlying: URLError(.badURL))
        }
        print("DEBUG: Unwrangle request URL: \(requestURL.absoluteString)")

        // Build request
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // Execute request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UnwrangleError.networkError(underlying: error)
        }

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnwrangleError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw UnwrangleError.invalidAPIKey
        case 404:
            throw UnwrangleError.productNotFound
        case 429:
            throw UnwrangleError.rateLimited
        default:
            throw UnwrangleError.networkError(underlying: URLError(.badServerResponse))
        }

        // Decode response
        let apiResponse: UnwrangleAPIResponse
        do {
            apiResponse = try JSONDecoder().decode(UnwrangleAPIResponse.self, from: data)
        } catch {
            throw UnwrangleError.decodingError(underlying: error)
        }

        // Check for successful response with detail
        guard let detail = apiResponse.detail else {
            throw UnwrangleError.productNotFound
        }

        // Check for ingredients
        guard let ingredients = detail.ingredients, !ingredients.isEmpty else {
            throw UnwrangleError.ingredientsNotAvailable
        }

        // Map to our domain model
        return UnwrangleProduct(
            name: detail.name,
            brand: detail.brand,
            ingredients: ingredients,
            price: detail.price,
            autoshipPrice: detail.autoshipPrice,
            imageURL: detail.images?.first.flatMap { URL(string: $0) },
            rating: detail.rating,
            reviewCount: detail.reviewCount
        )
    }
}

// MARK: - API Response Model

/// Root response wrapper - actual data is nested in `detail`
private struct UnwrangleAPIResponse: Decodable {
    let success: Bool
    let detail: UnwrangleDetail?
}

/// The actual product detail from Unwrangle
private struct UnwrangleDetail: Decodable {
    let name: String
    let brand: String?
    let price: Double?
    let autoshipPrice: Double?
    let listPrice: Double?
    let currency: String?
    let images: [String]?
    let rating: Double?
    let reviewCount: Int?
    let ingredients: [String]?
    let specifications: [Specification]?
    let description: String?
    let inStock: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case price
        case autoshipPrice = "autoship_price"
        case listPrice = "list_price"
        case currency
        case images
        case rating
        case reviewCount = "review_count"
        case ingredients
        case specifications
        case description
        case inStock = "in_stock"
    }
}

private struct Specification: Decodable {
    let name: String
    let value: String
}

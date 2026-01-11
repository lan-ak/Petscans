import Foundation

/// Protocol for fetching product data from Unwrangle Chewy API
protocol UnwrangleServiceProtocol: Sendable {
    /// Fetch product details including ingredients from a Chewy URL
    /// - Parameter url: The Chewy product URL
    /// - Returns: Product details including ingredients
    /// - Throws: UnwrangleError on failure
    func fetchChewyProduct(url: URL) async throws -> UnwrangleProduct
}

/// Product data returned from Unwrangle API
struct UnwrangleProduct: Sendable {
    let name: String
    let brand: String?
    let ingredients: [String]
    let price: Double?
    let autoshipPrice: Double?
    let imageURL: URL?
    let rating: Double?
    let reviewCount: Int?
}

/// Errors that can occur during Unwrangle API operations
enum UnwrangleError: LocalizedError {
    case invalidAPIKey
    case productNotFound
    case ingredientsNotAvailable
    case rateLimited
    case networkError(underlying: Error)
    case decodingError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid Unwrangle API key"
        case .productNotFound:
            return "Product not found on Chewy"
        case .ingredientsNotAvailable:
            return "Ingredients not available for this product"
        case .rateLimited:
            return "API rate limit exceeded"
        case .networkError:
            return "Network error fetching product"
        case .decodingError:
            return "Failed to parse product data"
        }
    }
}

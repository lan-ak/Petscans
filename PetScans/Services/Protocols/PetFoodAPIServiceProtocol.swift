import Foundation

/// Errors that can occur during API operations
enum APIError: LocalizedError {
    case networkError(underlying: Error)
    case productNotFound
    case invalidResponse
    case decodingError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .productNotFound:
            return "Product not found in database"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to process response"
        }
    }
}

/// Protocol for pet food product lookup service
protocol PetFoodAPIServiceProtocol: Sendable {
    /// Look up a product by barcode
    /// - Parameter barcode: The barcode string to look up
    /// - Returns: Product information if found
    /// - Throws: APIError if lookup fails
    func lookupProduct(barcode: String) async throws -> ProductInfo
}

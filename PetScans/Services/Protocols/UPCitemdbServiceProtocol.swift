import Foundation

// MARK: - UPCitemdb Response Models

/// Response from UPCitemdb API lookup
struct UPCitemdbResponse: Codable {
    let code: String
    let total: Int
    let offset: Int
    let items: [UPCitemdbItem]
}

/// Individual product item from UPCitemdb
struct UPCitemdbItem: Codable {
    let ean: String?
    let upc: String?
    let title: String?
    let brand: String?
    let model: String?
    let description: String?
    let images: [String]?

    /// Best available product name from available fields
    var displayName: String? {
        title ?? model
    }

    /// Search query combining brand and product name for web search
    var searchQuery: String? {
        if let brand = brand, let name = displayName {
            return "\(brand) \(name)"
        }
        return displayName ?? brand
    }
}

// MARK: - UPCitemdb Errors

/// Errors specific to UPCitemdb operations
enum UPCitemdbError: LocalizedError {
    case productNotFound
    case rateLimited
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
    case invalidBarcode

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Barcode not recognized"
        case .rateLimited:
            return "Service temporarily unavailable"
        case .networkError:
            return "Network connection failed"
        case .decodingError:
            return "Failed to process response"
        case .invalidBarcode:
            return "Invalid barcode format"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .productNotFound:
            return "This barcode isn't in our product database. Try taking a photo of the ingredients instead."
        case .rateLimited:
            return "We've reached the daily lookup limit. Please try again tomorrow or take a photo of the ingredients."
        case .networkError:
            return "Please check your internet connection and try again."
        case .decodingError:
            return "Something went wrong. Please try again or take a photo of the ingredients."
        case .invalidBarcode:
            return "The scanned barcode appears to be invalid. Please try scanning again."
        }
    }
}

// MARK: - Protocol

/// Protocol for UPCitemdb barcode lookup service
protocol UPCitemdbServiceProtocol: Sendable {
    /// Look up a barcode using UPCitemdb API
    /// - Parameter barcode: The barcode to look up
    /// - Returns: Product information from UPCitemdb
    /// - Throws: UPCitemdbError on failure
    func lookupBarcode(_ barcode: String) async throws -> UPCitemdbItem
}

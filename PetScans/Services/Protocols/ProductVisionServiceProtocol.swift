import Foundation
import UIKit

// MARK: - Product Identification Model

/// Product identification result from vision API analysis of packaging photo
struct ProductIdentification: Codable, Sendable {
    let brand: String?
    let productName: String?
    let species: String?
    let confidence: Double
    let primaryProtein: String?  // e.g., "Chicken", "Salmon", "Beef"
    let primaryCarb: String?     // e.g., "Rice", "Sweet Potato", "Grain-Free"

    /// Combined search query for Serper (brand + product name + protein + carb)
    var searchQuery: String? {
        guard let brand = brand, let name = productName,
              !brand.isEmpty, !name.isEmpty else { return nil }
        var query = "\(brand) \(name)"
        if let protein = primaryProtein, !protein.isEmpty {
            query += " \(protein)"
        }
        if let carb = primaryCarb, !carb.isEmpty {
            query += " \(carb)"
        }
        return query
    }

    /// Whether identification has enough confidence to proceed
    var isUsable: Bool {
        searchQuery != nil && confidence >= 0.5
    }
}

// MARK: - Product Vision Errors

enum ProductVisionError: LocalizedError {
    case imageEncodingFailed
    case noProductFound
    case lowConfidence(Double)
    case networkError(underlying: Error)
    case invalidAPIKey
    case rateLimited
    case decodingError(underlying: Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to process image"
        case .noProductFound:
            return "Could not identify product"
        case .lowConfidence(let confidence):
            return "Low confidence identification (\(Int(confidence * 100))%)"
        case .networkError:
            return "Network connection failed"
        case .invalidAPIKey:
            return "Invalid API key"
        case .rateLimited:
            return "Rate limit exceeded"
        case .decodingError:
            return "Failed to parse response"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

// MARK: - Protocol

/// Protocol for identifying pet food products from packaging images
protocol ProductVisionServiceProtocol: Sendable {
    /// Identify a pet food product from a packaging photo
    /// - Parameter image: Photo of the product packaging (front)
    /// - Returns: Identified product details (brand, name, species)
    func identifyProduct(from image: UIImage) async throws -> ProductIdentification
}

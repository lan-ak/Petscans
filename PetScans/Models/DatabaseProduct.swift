import Foundation
import GRDB

/// Represents a product stored in the local SQLite database
struct DatabaseProduct: Codable {
    var code: String
    var productName: String?
    var brands: String?
    var ingredientsText: String?
    var imageUrl: String?
    var imageFrontUrl: String?
    var lastModifiedT: Int64?
    var cachedAt: Int64

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case ingredientsText = "ingredients_text"
        case imageUrl = "image_url"
        case imageFrontUrl = "image_front_url"
        case lastModifiedT = "last_modified_t"
        case cachedAt = "cached_at"
    }

    init(code: String, productName: String?, brands: String?, ingredientsText: String?, imageUrl: String?, imageFrontUrl: String?, lastModifiedT: Int64?, cachedAt: Int64 = Int64(Date().timeIntervalSince1970)) {
        self.code = code
        self.productName = productName
        self.brands = brands
        self.ingredientsText = ingredientsText
        self.imageUrl = imageUrl
        self.imageFrontUrl = imageFrontUrl
        self.lastModifiedT = lastModifiedT
        self.cachedAt = cachedAt
    }

    /// Convert to ProductInfo for app use
    func toProductInfo() -> ProductInfo {
        ProductInfo(
            found: true,
            productName: productName,
            brand: brands,
            ingredientsText: ingredientsText,
            imageUrl: imageFrontUrl ?? imageUrl
        )
    }
}

// MARK: - GRDB Extensions
extension DatabaseProduct: FetchableRecord, PersistableRecord {
    static let databaseTableName = "products"
}

// MARK: - V2 API Response Models
struct V2SearchResponse: Codable {
    let count: Int
    let page: Int
    let pageCount: Int
    let pageSize: Int
    let products: [V2Product]

    enum CodingKeys: String, CodingKey {
        case count
        case page
        case pageCount = "page_count"
        case pageSize = "page_size"
        case products
    }
}

struct V2Product: Codable {
    let code: String?
    let productName: String?
    let brands: String?
    let ingredientsText: String?
    let imageUrl: String?
    let imageFrontUrl: String?
    let lastModifiedT: Int64?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case ingredientsText = "ingredients_text"
        case imageUrl = "image_url"
        case imageFrontUrl = "image_front_url"
        case lastModifiedT = "last_modified_t"
    }

    /// Convert V2 API product to DatabaseProduct
    func toDatabaseProduct() -> DatabaseProduct? {
        guard let code = code else { return nil }
        return DatabaseProduct(
            code: code,
            productName: productName,
            brands: brands,
            ingredientsText: ingredientsText,
            imageUrl: imageUrl,
            imageFrontUrl: imageFrontUrl,
            lastModifiedT: lastModifiedT
        )
    }
}

struct V2ProductResponse: Codable {
    let code: String?
    let status: Int
    let statusVerbose: String?
    let product: V2Product?

    enum CodingKeys: String, CodingKey {
        case code
        case status
        case statusVerbose = "status_verbose"
        case product
    }
}

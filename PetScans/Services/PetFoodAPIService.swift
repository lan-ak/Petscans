import Foundation

/// Service for looking up products on Open Pet Food Facts API with offline-first caching
actor PetFoodAPIService: PetFoodAPIServiceProtocol {
    private let baseURL = "https://world.openpetfoodfacts.org/api/v2"
    private let session: URLSession
    private let database: LocalProductDatabase

    init(session: URLSession = .shared, database: LocalProductDatabase = LocalProductDatabase()) {
        self.session = session
        self.database = database
    }

    /// Look up a product by barcode (offline-first with API fallback)
    /// - Parameter barcode: The barcode to look up
    /// - Returns: Product information
    /// - Throws: APIError on failure
    func lookupProduct(barcode: String) async throws -> ProductInfo {
        // Validate barcode format (basic validation)
        let cleanedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedBarcode.isEmpty else {
            throw APIError.productNotFound
        }

        // 1. Try local database first (offline-first)
        if let cachedProduct = try? await database.lookupProduct(barcode: cleanedBarcode) {
            return cachedProduct
        }

        // 2. Fallback to V2 API
        let product = try await fetchFromV2API(barcode: cleanedBarcode)

        // 3. Cache the result for future offline use
        Task.detached { [database] in
            let dbProduct = DatabaseProduct(
                code: cleanedBarcode,
                productName: product.productName,
                brands: product.brand,
                ingredientsText: product.ingredientsText,
                imageUrl: product.imageUrl,
                imageFrontUrl: product.imageUrl,
                lastModifiedT: nil
            )
            try? await database.upsertProduct(dbProduct)
        }

        return product
    }

    /// Fetch product from V2 API
    private func fetchFromV2API(barcode: String) async throws -> ProductInfo {
        guard let url = URL(string: "\(baseURL)/product/\(barcode)") else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("PetScans/1.0 (iOS Swift App)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 404:
            throw APIError.productNotFound
        default:
            throw APIError.invalidResponse
        }

        let apiResponse: V2ProductResponse
        do {
            apiResponse = try JSONDecoder().decode(V2ProductResponse.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error)
        }

        guard apiResponse.status == 1, let product = apiResponse.product, let _ = product.code else {
            throw APIError.productNotFound
        }

        return ProductInfo(
            found: true,
            productName: product.productName,
            brand: product.brands,
            ingredientsText: product.ingredientsText,
            imageUrl: product.imageFrontUrl ?? product.imageUrl
        )
    }
}

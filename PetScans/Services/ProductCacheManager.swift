import Foundation
import Combine

/// Manages downloading and syncing the pet food product database
@MainActor
class ProductCacheManager: ObservableObject {
    static let shared = ProductCacheManager()

    @Published var syncState: SyncState = .idle
    @Published var progress: Double = 0.0
    @Published var productCount: Int = 0
    @Published var lastSyncDate: Date?
    @Published var databaseSizeMB: Double = 0

    private let database = LocalProductDatabase()
    private let baseURL = "https://world.openpetfoodfacts.org/api/v2"
    private let session = URLSession.shared

    enum SyncState: Equatable {
        case idle
        case syncing(page: Int, totalPages: Int)
        case completed
        case failed(Error)

        static func == (lhs: SyncState, rhs: SyncState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.completed, .completed):
                return true
            case let (.syncing(p1, t1), .syncing(p2, t2)):
                return p1 == p2 && t1 == t2
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }

    private init() {}

    /// Initialize the database
    func initialize() async {
        do {
            try await database.setup()
            await refreshStats()

            // Auto-sync on first launch if database is empty
            if productCount == 0 {
                print("First launch detected - auto-syncing product database...")
                await fullSync()
            }
        } catch {
            print("Failed to initialize database: \(error)")
        }
    }

    /// Refresh statistics (product count, last sync date, file size)
    func refreshStats() async {
        do {
            productCount = try await database.getProductCount()

            if let timestamp = try await database.getLastSyncTimestamp() {
                lastSyncDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
            }

            databaseSizeMB = try await database.getDatabaseSize()
        } catch {
            print("Failed to refresh stats: \(error)")
        }
    }

    /// Perform full sync of all pet food products
    func fullSync() async {
        syncState = .syncing(page: 0, totalPages: 0)
        progress = 0.0

        do {
            // Fetch first page to get total count
            let firstPage = try await fetchProductsPage(page: 1)
            let totalPages = firstPage.pageCount

            syncState = .syncing(page: 1, totalPages: totalPages)

            // Process first page
            let products = firstPage.products.compactMap { $0.toDatabaseProduct() }
            try await database.upsertProducts(products)

            progress = 1.0 / Double(totalPages)

            // Fetch remaining pages
            for pageNum in 2...totalPages {
                syncState = .syncing(page: pageNum, totalPages: totalPages)

                let page = try await fetchProductsPage(page: pageNum)
                let pageProducts = page.products.compactMap { $0.toDatabaseProduct() }
                try await database.upsertProducts(pageProducts)

                progress = Double(pageNum) / Double(totalPages)

                // Respect rate limits (10 req/min for search)
                if pageNum < totalPages {
                    try await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds between requests
                }
            }

            // Update last sync timestamp
            let now = Int64(Date().timeIntervalSince1970)
            try await database.setLastSyncTimestamp(now)

            await refreshStats()
            syncState = .completed

            // Auto-reset to idle after 3 seconds
            try await Task.sleep(nanoseconds: 3_000_000_000)
            syncState = .idle

        } catch {
            syncState = .failed(error)
            print("Sync failed: \(error)")
        }
    }

    /// Fetch a single page of products from the V2 search API
    private func fetchProductsPage(page: Int) async throws -> V2SearchResponse {
        let fields = "code,product_name,brands,ingredients_text,image_url,image_front_url,last_modified_t"
        let urlString = "\(baseURL)/search?categories_tags_en=pet-food&page_size=100&page=\(page)&fields=\(fields)"

        guard let url = URL(string: urlString) else {
            throw CacheError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("PetScans/1.0 (iOS Swift App)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CacheError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw CacheError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(V2SearchResponse.self, from: data)
    }

    /// Clear the entire cache
    func clearCache() async {
        do {
            try await database.clearAllProducts()
            try await database.setLastSyncTimestamp(0)
            await refreshStats()
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
}

enum CacheError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}

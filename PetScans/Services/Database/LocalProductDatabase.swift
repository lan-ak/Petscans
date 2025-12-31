import Foundation
import GRDB

/// Local SQLite database for caching pet food products
actor LocalProductDatabase {
    private var dbQueue: DatabaseQueue?
    private let fileManager = FileManager.default

    init() {}

    /// Initialize the database connection and schema
    func setup() async throws {
        let databaseURL = try getDatabaseURL()
        dbQueue = try DatabaseQueue(path: databaseURL.path)

        try await dbQueue?.write { db in
            // Create products table
            try db.create(table: "products", ifNotExists: true) { t in
                t.column("code", .text).primaryKey()
                t.column("product_name", .text)
                t.column("brands", .text)
                t.column("ingredients_text", .text)
                t.column("image_url", .text)
                t.column("image_front_url", .text)
                t.column("last_modified_t", .integer)
                t.column("cached_at", .integer).notNull()
            }

            // Create index for faster lookups by last modified time
            try db.create(index: "idx_last_modified", on: "products", columns: ["last_modified_t"], ifNotExists: true)

            // Create metadata table for tracking sync state
            try db.create(table: "metadata", ifNotExists: true) { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text)
            }
        }
    }

    /// Lookup a product by barcode
    func lookupProduct(barcode: String) async throws -> ProductInfo? {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notInitialized
        }

        let product = try await dbQueue.read { db in
            try DatabaseProduct
                .filter(Column("code") == barcode)
                .fetchOne(db)
        }

        return product?.toProductInfo()
    }

    /// Insert or update a single product
    func upsertProduct(_ product: DatabaseProduct) async throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notInitialized
        }

        try await dbQueue.write { db in
            try product.save(db)
        }
    }

    /// Bulk insert or update products
    func upsertProducts(_ products: [DatabaseProduct]) async throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notInitialized
        }

        try await dbQueue.write { db in
            for product in products {
                try product.save(db)
            }
        }
    }

    /// Get total product count
    func getProductCount() async throws -> Int {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notInitialized
        }

        return try await dbQueue.read { db in
            try DatabaseProduct.fetchCount(db)
        }
    }

    /// Get metadata value by key
    func getMetadata(key: String) async throws -> String? {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notInitialized
        }

        return try await dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM metadata WHERE key = ?", arguments: [key])
        }
    }

    /// Set metadata value
    func setMetadata(key: String, value: String) async throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notInitialized
        }

        try await dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
                arguments: [key, value]
            )
        }
    }

    /// Get the last sync timestamp
    func getLastSyncTimestamp() async throws -> Int64? {
        if let value = try await getMetadata(key: "last_sync_timestamp"),
           let timestamp = Int64(value) {
            return timestamp
        }
        return nil
    }

    /// Set the last sync timestamp
    func setLastSyncTimestamp(_ timestamp: Int64) async throws {
        try await setMetadata(key: "last_sync_timestamp", value: String(timestamp))
    }

    /// Clear all products (for testing or reset)
    func clearAllProducts() async throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notInitialized
        }

        _ = try await dbQueue.write { db in
            try DatabaseProduct.deleteAll(db)
        }
    }

    /// Get database file URL in Application Support directory
    private func getDatabaseURL() throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let dbDirectory = appSupport.appendingPathComponent("PetScans", isDirectory: true)
        try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)

        return dbDirectory.appendingPathComponent("products.db")
    }

    /// Get database file size in MB
    func getDatabaseSize() async throws -> Double {
        let databaseURL = try getDatabaseURL()

        guard fileManager.fileExists(atPath: databaseURL.path) else {
            return 0
        }

        let attributes = try fileManager.attributesOfItem(atPath: databaseURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        return Double(fileSize) / 1_048_576.0 // Convert to MB
    }
}

enum DatabaseError: LocalizedError {
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database has not been initialized. Call setup() first."
        }
    }
}

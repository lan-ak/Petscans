import Foundation
import GRDB

/// A product resolved from the bundled catalog: barcode → ingredients, plus the metadata
/// needed to score and display it without any network call.
struct CatalogProduct: Equatable {
    let gtin: String
    let name: String
    let brand: String?
    let imageUrl: String?
    let ingredients: String
    let species: Species
    let category: Category
    let tier: String
}

/// Read-only accessor over `catalog.sqlite`, the barcode index bundled in the app.
///
/// This is the first use of GRDB in the project — the package is already linked to the app
/// target, so no new dependency. The database is opened read-only and lazily on first
/// lookup, not at launch: `PetScansApp.deferredInit` is already loading fonts, the
/// ingredient database and running pet migration, and the catalog isn't needed until the
/// user actually scans.
actor LocalCatalogStore {
    static let shared = LocalCatalogStore()

    private var queue: DatabaseQueue?
    private var openFailed = false

    /// Number of products in the catalog, or 0 if it couldn't be opened.
    func productCount() -> Int {
        guard let db = database() else { return 0 }
        return (try? db.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM products") }) ?? 0
    }

    /// Catalog build version (yyyymmdd), for telemetry and display.
    func version() -> String? {
        guard let db = database() else { return nil }
        return try? db.read {
            try String.fetchOne($0, sql: "SELECT value FROM meta WHERE key = 'version'")
        } ?? nil
    }

    /// Look up a canonical GTIN-14. Single indexed point query, sub-millisecond.
    func product(gtin: String) -> CatalogProduct? {
        guard let db = database() else { return nil }
        return try? db.read { dbc -> CatalogProduct? in
            guard let row = try Row.fetchOne(
                dbc,
                sql: """
                SELECT gtin, name, brand, image_url, ingredients, species, category, tier
                FROM products WHERE gtin = ?
                """,
                arguments: [gtin]
            ) else { return nil }

            // A row whose species/category somehow isn't a known enum case is unusable for
            // scoring; treat it as a miss rather than defaulting and mis-scoring.
            guard let species = Species(rawValue: row["species"]),
                  let category = Category(rawValue: row["category"]) else { return nil }

            return CatalogProduct(
                gtin: row["gtin"],
                name: row["name"],
                brand: row["brand"],
                imageUrl: row["image_url"],
                ingredients: row["ingredients"],
                species: species,
                category: category,
                tier: row["tier"]
            )
        }
    }

    // MARK: - Private

    private func database() -> DatabaseQueue? {
        if let queue { return queue }
        if openFailed { return nil }

        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "sqlite") else {
            #if DEBUG
            print("LocalCatalogStore: catalog.sqlite not found in bundle")
            #endif
            openFailed = true
            return nil
        }

        var config = Configuration()
        config.readonly = true
        do {
            let q = try DatabaseQueue(path: url.path, configuration: config)
            queue = q
            return q
        } catch {
            #if DEBUG
            print("LocalCatalogStore: failed to open catalog.sqlite: \(error)")
            #endif
            openFailed = true
            return nil
        }
    }
}

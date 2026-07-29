import Foundation
import Compression
import GRDB

/// Inflate the `ingredients` column, stored as a raw-DEFLATE blob to keep the bundled
/// `catalog.sqlite` small (the ingredient text is ~60% of the file). Raw DEFLATE decodes
/// natively via Apple's Compression framework — `COMPRESSION_ZLIB` is raw DEFLATE, matching
/// the build tool's `zlib.deflateRawSync`. `meta.ingredients_codec` records the format.
private func inflateIngredients(_ data: Data) -> String {
    if data.isEmpty { return "" }
    // Ingredient lists are a few hundred bytes to ~2 KB decompressed; 64 KB is ample headroom.
    let capacity = 64 * 1024
    let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
    defer { dst.deallocate() }
    let written = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int in
        guard let src = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
        return compression_decode_buffer(dst, capacity, src, data.count, nil, COMPRESSION_ZLIB)
    }
    guard written > 0 else { return "" }
    return String(bytes: UnsafeBufferPointer(start: dst, count: written), encoding: .utf8) ?? ""
}

/// Read and inflate the `ingredients` blob from a catalog row.
private func ingredientsText(_ row: Row) -> String {
    if let data = row["ingredients"] as Data? { return inflateIngredients(data) }
    return ""
}

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

    /// Free-text search over product name and brand. Used by the shared catalog
    /// search screen (onboarding + the Identify Product flow); the scan path uses
    /// `product(gtin:)`.
    ///
    /// Multi-term / fuzzy: the query is split into words and every word must appear
    /// somewhere in the name OR brand (AND across words, order-independent). So
    /// "purina chicken" matches "Purina Pro Plan Chicken & Rice" even though those
    /// words aren't adjacent and the exact product name was never typed. A plain
    /// LIKE per term is fine over ~24k rows — no FTS index or DB rebuild needed.
    ///
    /// Rows without ingredient text are pushed to the bottom rather than dropped: a
    /// hit the user recognises but can't be scored is still worth showing over
    /// silence, but a scoreable hit is preferred so the results reveal isn't empty.
    /// Shorter names rank first so canonical products beat long variant SKUs.
    func search(query: String, limit: Int = 30) -> [CatalogProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, let db = database() else { return [] }

        // Escape LIKE wildcards so a term like "50%" doesn't match everything.
        func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_")
        }

        // Cap the term count so a pathological paste can't build a huge WHERE clause.
        let terms = trimmed.split(whereSeparator: { $0.isWhitespace }).prefix(6).map(String.init)
        guard !terms.isEmpty else { return [] }

        let clause = terms
            .map { _ in "(name LIKE ? ESCAPE '\\' OR brand LIKE ? ESCAPE '\\')" }
            .joined(separator: " AND ")
        var arguments: [DatabaseValueConvertible] = terms.flatMap { term -> [String] in
            let pattern = "%\(escape(term))%"
            return [pattern, pattern]
        }
        arguments.append(limit)

        let rows = (try? db.read { dbc -> [Row] in
            try Row.fetchAll(
                dbc,
                sql: """
                SELECT gtin, name, brand, image_url, ingredients, species, category, tier
                FROM products
                WHERE \(clause)
                ORDER BY (ingredients IS NULL OR length(ingredients) = 0) ASC, length(name) ASC
                LIMIT ?
                """,
                arguments: StatementArguments(arguments)
            )
        }) ?? []

        return rows.compactMap { row in
            // Same contract as product(gtin:): a row whose species/category isn't a
            // known enum case can't be scored, so drop it rather than mis-scoring.
            guard let species = Species(rawValue: row["species"]),
                  let category = Category(rawValue: row["category"]) else { return nil }
            return CatalogProduct(
                gtin: row["gtin"],
                name: row["name"],
                brand: row["brand"],
                imageUrl: row["image_url"],
                ingredients: ingredientsText(row),
                species: species,
                category: category,
                tier: row["tier"]
            )
        }
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
                ingredients: ingredientsText(row),
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

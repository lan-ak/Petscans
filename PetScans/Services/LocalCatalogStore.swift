import Foundation
import GRDB

/// Read and inflate the `ingredients` blob from a catalog row.
/// The codec itself lives in `IngredientsBlob.swift`, shared with `matchkit`.
private func ingredientsText(_ row: Row) -> String {
    if let data = row["ingredients"] as Data? { return inflateIngredientsBlob(data) }
    return ""
}

/// Fold typed text into the shape `product_groups.search_text` is stored in: no accents, no
/// apostrophes, punctuation reduced to spaces. That is what makes "hills" match "Hill's" and
/// "grain free" match "Grain-Free" — people don't type the punctuation.
///
/// This is the Swift half of `foldForSearch` in `tools/petcatalog/scripts/petcatalog/group.ts`
/// and must stay identical to it. The two run on opposite sides of the same comparison, so any
/// difference shows up as products that can't be found rather than as an error.
func foldForSearch(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        .replacingOccurrences(of: "['’`]", with: "", options: .regularExpression)
        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .joined(separator: " ")
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

    /// How many catalog rows this listing stands for — the pack sizes of the same recipe
    /// that search folds into one result (see `product_groups` in the catalog, built by
    /// `petcatalog group`). 1 for a scanned product, which is always a single GTIN.
    var variantCount: Int = 1
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
    /// LIKE per term is fine over ~23k listings — no FTS index or DB rebuild needed.
    ///
    /// One row per *recipe*, not per SKU: the catalog lists every pack size separately, so
    /// an ungrouped search spends most of a screen on "…, 4 lb / 11 lb / 24 lb" of the same
    /// food. This reads `product_groups` instead, which names one representative row per
    /// group. Terms match `search_text`, which already carries the sibling names, so typing
    /// "24 lb" still finds the listing when the 4 lb row is the one shown — and because the
    /// filter touches only that narrow table, `products` is joined for the survivors rather
    /// than for every group (~4 ms a query against ~13 ms if the LIKE reads `products`).
    /// Grouping is built by `petcatalog group`; a catalog predating it falls back to a flat
    /// row search.
    ///
    /// Results are ranked by how well the row matches what was actually typed: the whole
    /// folded query as a leading phrase first, then as a phrase anywhere, then rows that
    /// only matched term-by-term. Catalog tier breaks the tie, and shorter names break
    /// that, so canonical products beat long variant SKUs.
    ///
    /// The previous ordering led with `(ingredients IS NULL OR length(ingredients) = 0)`,
    /// which reads as "unscoreable rows last" but is constant 0 across all 31,142 rows —
    /// `ingredients` is `NOT NULL` and holds a DEFLATE blob whose minimum length is 6. So
    /// the whole ORDER BY collapsed to `length(name) ASC`, i.e. shortest name wins, with
    /// no relevance term at all: "purina" returned `FF PTE 12CT WF` and "Nutro" returned
    /// `Merchandise`.
    func search(query: String, limit: Int = 30) -> [CatalogProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, let db = database() else { return [] }

        // Escape LIKE wildcards so a term like "50%" doesn't match everything.
        func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_")
        }

        let grouped = groupingAvailable(db)

        // Cap the term count so a pathological paste can't build a huge WHERE clause. On the
        // grouped path the query travels through the same fold that built `search_text`, which
        // is what lets "hills" find "Hill's" and "puree" find "Purée"; the fallback keeps the
        // literal terms, because an ungrouped catalog stores names unfolded.
        let terms = (grouped ? foldForSearch(trimmed) : trimmed)
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(6)
            .map(String.init)
        guard !terms.isEmpty else { return [] }
        let fields = grouped ? ["g.search_text"] : ["name", "brand"]
        let clause = terms
            .map { _ in "(" + fields.map { "\($0) LIKE ? ESCAPE '\\'" }.joined(separator: " OR ") + ")" }
            .joined(separator: " AND ")
        // The whole query as one phrase, matched against the same haystack the WHERE clause
        // filters on. `instr` rather than LIKE, so the phrase needs no wildcard escaping.
        //
        // Both sides are padded with a space so the phrase can only match whole words.
        // Without the padding "beef" matches the start of "beefeaters" and a peanut-butter
        // biscuit outranks every actual beef product; `search_text` is already folded to
        // single-space-separated tokens, so padding is all a word boundary needs.
        //
        // `tier` is TEXT 'S' | 'A' | 'B' with S best, so it cannot be sorted directly —
        // plain `ASC` would rank the 306 best-described products last.
        let phrase = " " + (grouped ? foldForSearch(trimmed) : trimmed.lowercased()) + " "
        let haystack = grouped
            ? "' ' || g.search_text || ' '"
            : "' ' || lower(name || ' ' || COALESCE(brand, '')) || ' '"
        let nameColumn = grouped ? "p.name" : "name"
        let tierColumn = grouped ? "p.tier" : "tier"
        let ranking = """
                      CASE WHEN instr(\(haystack), ?) = 1 THEN 0
                           WHEN instr(\(haystack), ?) > 0 THEN 1
                           ELSE 2 END ASC,
                      CASE \(tierColumn) WHEN 'S' THEN 0 WHEN 'A' THEN 1 ELSE 2 END ASC,
                      length(\(nameColumn)) ASC
                      """

        var arguments: [DatabaseValueConvertible] = terms.flatMap { term -> [String] in
            let pattern = "%\(escape(term))%"
            return Array(repeating: pattern, count: fields.count)
        }
        // Positional binding: these two sit between the WHERE patterns and LIMIT in the
        // statement below, so they must be appended in exactly that order.
        arguments.append(phrase)
        arguments.append(phrase)
        arguments.append(limit)

        let sql = grouped
            ? """
              SELECT p.gtin, p.name, p.brand, p.image_url, p.ingredients, p.species, p.category, p.tier,
                     g.variant_count
              FROM product_groups g
              JOIN products p ON p.gtin = g.gtin
              WHERE \(clause)
              ORDER BY \(ranking)
              LIMIT ?
              """
            : """
              SELECT gtin, name, brand, image_url, ingredients, species, category, tier
              FROM products
              WHERE \(clause)
              ORDER BY \(ranking)
              LIMIT ?
              """

        let rows = (try? db.read { dbc -> [Row] in
            try Row.fetchAll(dbc, sql: sql, arguments: StatementArguments(arguments))
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
                tier: row["tier"],
                variantCount: grouped ? (row["variant_count"] ?? 1) : 1
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

    /// Whether this catalog carries size-variant grouping. Older bundled catalogs predate
    /// `petcatalog group`, and search has to keep working against them rather than throwing
    /// "no such table" on every keystroke. Resolved once and cached.
    private var hasGrouping: Bool?

    private func groupingAvailable(_ db: DatabaseQueue) -> Bool {
        if let hasGrouping { return hasGrouping }
        let exists = (try? db.read { try $0.tableExists("product_groups") }) ?? false
        hasGrouping = exists
        return exists
    }

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

import Foundation
import SQLite3

/// Read-only reader for the bundled `catalog.sqlite`.
///
/// Uses the SQLite C API directly rather than GRDB so this tool has no package
/// dependencies. The one detail that must match the app exactly — the raw-DEFLATE
/// codec for the `ingredients` column — is not reimplemented here: it comes from
/// the shared `inflateIngredientsBlob`.
struct Catalog {
    struct Product {
        let gtin: String
        let name: String
        let brand: String?
        let ingredients: String
        let species: Species
        let category: Category
        let tier: String
    }

    private let handle: OpaquePointer

    init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK, let db else {
            throw Failure("cannot open catalog at \(path)")
        }
        handle = db
    }

    /// `meta` is a key/value table carrying the catalog version, build date and
    /// codec. Reported alongside every measurement so a number can always be tied
    /// back to the catalog it came from.
    func meta() -> [String: String] {
        var result: [String: String] = [:]
        forEachRow("SELECT key, value FROM meta") { stmt in
            guard let k = sqlite3_column_text(stmt, 0), let v = sqlite3_column_text(stmt, 1) else { return }
            result[String(cString: k)] = String(cString: v)
        }
        return result
    }

    func productCount() -> Int {
        var n = 0
        forEachRow("SELECT COUNT(*) FROM products") { stmt in n = Int(sqlite3_column_int64(stmt, 0)) }
        return n
    }

    /// Streams every product. Streaming rather than returning an array keeps peak
    /// memory flat across 27k rows of inflated ingredient text.
    func forEachProduct(_ body: (Product) -> Void) {
        let sql = "SELECT gtin, name, brand, ingredients, species, category, tier FROM products"
        forEachRow(sql) { stmt in
            let blobLength = Int(sqlite3_column_bytes(stmt, 3))
            let blob = sqlite3_column_blob(stmt, 3)
            let data = (blob != nil && blobLength > 0)
                ? Data(bytes: blob!, count: blobLength)
                : Data()

            body(Product(
                gtin: text(stmt, 0) ?? "",
                name: text(stmt, 1) ?? "",
                brand: text(stmt, 2),
                ingredients: inflateIngredientsBlob(data),
                species: Species(rawValue: text(stmt, 4) ?? "") ?? .dog,
                category: Category(rawValue: text(stmt, 5) ?? "") ?? .food,
                tier: text(stmt, 6) ?? ""
            ))
        }
    }

    private func text(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: c)
    }

    private func forEachRow(_ sql: String, _ body: (OpaquePointer?) -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW { body(stmt) }
    }
}

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

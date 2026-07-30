import Foundation
import XCTest
@testable import matchkit

/// Shared helpers for locating the repo's real data files.
///
/// The tests run against the *shipped* `ingredients.json` / `synonyms.json` /
/// `rules.json`, not miniature fakes. Those files are hand-maintained and have no
/// generator, no schema and (until now) no validation — so exercising the real
/// ones is the point, and `DataValidationTests` is what catches an editing
/// mistake before it reaches a device.
enum TestSupport {
    /// Repo root, derived from this file's location so the tests need no configuration.
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // matchkitTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // tools/matchkit
        .deletingLastPathComponent()   // tools
        .deletingLastPathComponent()   // <repo>

    static let dataDirectory = repoRoot.appendingPathComponent("PetScans/Data")

    /// The real bundled database, loaded once for the whole test run.
    static let liveData: IngredientData = IngredientData.load(from: .directory(dataDirectory))

    static func fixture(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        return try Data(contentsOf: try XCTUnwrap(url, "missing fixture \(name).json"))
    }
}

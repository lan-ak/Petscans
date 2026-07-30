import Foundation

/// Guards the one failure mode this tool's design creates.
///
/// `Sources/matchkit/Shared/` holds symlinks to the app's model and service
/// files. That gives zero drift for files that *are* linked — but says nothing
/// about a file that was added to the app and never linked here. The tool would
/// still compile and still print confident numbers, computed by a matcher missing
/// a rule. So the expected set is written down, and CI runs `matchkit doctor`.
///
/// When you add a file that matching or scoring depends on: add it to `expected`,
/// then `ln -s` it into `Shared/`. If it imports SwiftUI or touches app state, it
/// doesn't belong in the core — split it, the way `Models+UI.swift` and
/// `Matching+SharedDatabase.swift` are split.
enum Doctor {
    static let expected: [String] = [
        "PetScans/Models/AvoidanceGroup.swift",
        "PetScans/Models/Category.swift",
        "PetScans/Models/Ingredient.swift",
        "PetScans/Models/Ingredient+ComposedSummary.swift",
        "PetScans/Models/IngredientContent.swift",
        "PetScans/Models/MatchConfidence.swift",
        "PetScans/Models/MatchedIngredient.swift",
        "PetScans/Models/ProcessingLevel.swift",
        "PetScans/Models/RiskTier.swift",
        "PetScans/Models/Rule.swift",
        "PetScans/Models/RuleSeverity.swift",
        "PetScans/Models/ScoreBreakdown.swift",
        "PetScans/Models/Species.swift",
        "PetScans/Services/IngredientData.swift",
        "PetScans/Services/IngredientMatcher.swift",
        "PetScans/Services/IngredientsBlob.swift",
        "PetScans/Services/ScoreCalculator.swift"
    ]

    static func run(repoRoot: URL) -> Bool {
        let sharedDir = repoRoot.appendingPathComponent("tools/matchkit/Sources/matchkit/Shared")
        let fm = FileManager.default
        var ok = true

        let linked = (try? fm.contentsOfDirectory(atPath: sharedDir.path))?
            .filter { $0.hasSuffix(".swift") }
            .sorted() ?? []

        // 1. Every expected file is linked, and the link resolves.
        for path in expected {
            let name = (path as NSString).lastPathComponent
            let link = sharedDir.appendingPathComponent(name)
            guard linked.contains(name) else {
                print("MISSING  \(name) — expected a symlink to \(path)")
                ok = false
                continue
            }
            guard let target = try? fm.destinationOfSymbolicLink(atPath: link.path) else {
                print("NOT A SYMLINK  \(name) — it must link to the app's copy, not duplicate it")
                ok = false
                continue
            }
            let resolved = URL(fileURLWithPath: target, relativeTo: sharedDir).standardizedFileURL
            guard fm.fileExists(atPath: resolved.path) else {
                print("BROKEN   \(name) -> \(target)")
                ok = false
                continue
            }
            guard resolved.path.hasSuffix(path) else {
                print("WRONG TARGET  \(name) -> \(resolved.path), expected \(path)")
                ok = false
                continue
            }
        }

        // 2. Nothing is linked that isn't declared, so `expected` stays honest.
        let expectedNames = Set(expected.map { ($0 as NSString).lastPathComponent })
        for name in linked where !expectedNames.contains(name) {
            print("UNDECLARED  \(name) is linked but not listed in Doctor.expected")
            ok = false
        }

        // 3. Nothing in the core may import a UI framework — that's what would
        //    break the macOS build and force a reimplementation instead.
        for name in linked {
            let path = sharedDir.appendingPathComponent(name).path
            guard let source = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            for framework in ["SwiftUI", "UIKit", "SwiftData"] where source.contains("import \(framework)") {
                print("UI IMPORT  \(name) imports \(framework) — split it, see Models+UI.swift")
                ok = false
            }
        }

        print(ok
              ? "doctor: \(linked.count) shared sources linked, all resolve, none import UI frameworks"
              : "doctor: FAILED")
        return ok
    }
}

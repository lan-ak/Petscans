// swift-tools-version: 5.9
import PackageDescription

// matchkit — the offline measurement harness and test bed for ingredient
// matching and scoring.
//
// `Sources/matchkit/Shared/` is a set of SYMLINKS to the app's own model and
// service files, not copies. That is deliberate and load-bearing: this package
// reports what fraction of the catalog the matcher resolves, audits how a data
// change moves scores, and holds the regression tests for both — and all of that
// is only worth acting on if it exercises the code that actually ships. A
// reimplementation in TypeScript or Python would diverge quietly:
// `IngredientMatcher.normalizeToken` filters on `CharacterSet.alphanumerics`,
// which is Unicode general categories rather than `[a-z0-9]`, so a `\w`-based
// port disagrees on "açaí" and "d-alpha" and nothing would tell you.
//
// Everything lives in one module so the app's `internal` types stay internal —
// no `public` annotations added for the benefit of a dev tool. The tests reach
// them with `@testable import`.
//
//   swift test                  — matcher, scorer and persistence-decode tests
//   swift run matchkit doctor   — check the symlink set is complete
let package = Package(
    name: "matchkit",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "matchkit"),
        .testTarget(
            name: "matchkitTests",
            dependencies: ["matchkit"],
            resources: [.copy("Fixtures")]
        )
    ]
)

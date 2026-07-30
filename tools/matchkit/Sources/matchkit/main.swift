import Foundation

// matchkit — offline measurement for ingredient matching and scoring.
//
// Runs the app's own `IngredientMatcher` and `ScoreCalculator` (symlinked into
// Sources/matchkit/Shared) across the whole bundled catalog, so coverage numbers
// and score deltas can be reviewed before they reach a device.
//
//   swift run matchkit coverage
//   swift run matchkit misses --top 400
//   swift run matchkit baseline --out reports/baseline-<version>.json
//   swift run matchkit score-delta --baseline reports/baseline-<version>.json
//   swift run matchkit doctor

let usage = """
usage: matchkit <command> [options]

commands:
  coverage      match rate over the whole catalog, overall and by cohort
  misses        frequency-ranked unmatched tokens, with the recovery curve
  fuzzy-audit   how much of the match rate rests on ambiguous containment guesses
  calibration   why the 0-100 score doesn't discriminate
  baseline      write the full JSON baseline (coverage + per-product scores)
  score-delta   compare current scoring against a baseline file
  explain       one product: every token, how it matched, and the flags it earned
  doctor        check the shared-source symlinks are complete and resolvable

options:
  --gtin <gtin>      which product `explain` opens                 (required)
  --data <dir>       directory holding the four JSON data files
                     (default: <repo>/PetScans/Data)
  --catalog <path>   catalog.sqlite  (default: <repo>/PetScans/Data/catalog.sqlite)
  --top <n>          how many misses to list                       (default 100)
  --out <path>       where `baseline` writes                       (required)
  --baseline <path>  which baseline `score-delta` compares against (required)
"""

// MARK: - Arguments

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first, !command.hasPrefix("-") else {
    print(usage)
    exit(args.isEmpty ? 1 : 0)
}
args.removeFirst()

func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: "--\(name)"), i + 1 < args.count else { return nil }
    return args[i + 1]
}

/// The repo root, derived from this file's location, so the tool works from any
/// working directory without configuration.
let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // matchkit
    .deletingLastPathComponent()  // Sources
    .deletingLastPathComponent()  // tools/matchkit
    .deletingLastPathComponent()  // tools
    .deletingLastPathComponent()  // <repo>

let dataDir = URL(fileURLWithPath: option("data") ?? repoRoot.appendingPathComponent("PetScans/Data").path)
let catalogPath = option("catalog") ?? dataDir.appendingPathComponent("catalog.sqlite").path
let topN = Int(option("top") ?? "") ?? 100

func loadDatabase() -> IngredientData {
    let data = IngredientData.load(from: .directory(dataDir))
    guard !data.ingredients.isEmpty, !data.synonyms.isEmpty else {
        FileHandle.standardError.write(Data("no ingredient data found in \(dataDir.path)\n".utf8))
        exit(1)
    }
    return data
}

func openCatalog() -> Catalog {
    do { return try Catalog(path: catalogPath) } catch {
        FileHandle.standardError.write(Data("\(error)\n".utf8))
        exit(1)
    }
}

func requiredOption(_ name: String) -> String {
    guard let value = option(name) else {
        FileHandle.standardError.write(Data("missing --\(name)\n".utf8))
        exit(1)
    }
    return value
}

// MARK: - Commands

switch command {
case "coverage":
    let run = CatalogRun.run(catalog: openCatalog(), data: loadDatabase(), scoreProducts: false)
    print(run.coverageReport())

case "misses":
    let run = CatalogRun.run(catalog: openCatalog(), data: loadDatabase(), scoreProducts: false)
    print(run.missesReport(top: topN))

case "fuzzy-audit":
    print(FuzzyAudit.report(catalog: openCatalog(), data: loadDatabase(), top: topN))

case "calibration":
    print(Calibration.report(catalog: openCatalog(), data: loadDatabase()))

case "baseline":
    let out = requiredOption("out")
    let run = CatalogRun.run(catalog: openCatalog(), data: loadDatabase(), scoreProducts: true)
    print(run.coverageReport())
    print(run.scoreSummary())
    let url = URL(fileURLWithPath: out, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    do {
        try run.baselineJSON().write(to: url)
        print("wrote \(url.path)")
    } catch {
        FileHandle.standardError.write(Data("could not write baseline: \(error)\n".utf8))
        exit(1)
    }

case "score-delta":
    let baselinePath = requiredOption("baseline")
    guard let raw = try? Data(contentsOf: URL(fileURLWithPath: baselinePath)),
          let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
          let baselineScores = json["scores"] as? [String: [String: Any]] else {
        FileHandle.standardError.write(Data("cannot read baseline at \(baselinePath)\n".utf8))
        exit(1)
    }
    let run = CatalogRun.run(catalog: openCatalog(), data: loadDatabase(), scoreProducts: true)
    let baselineStamp = [
        "version": json["catalogVersion"] as? String ?? "?",
        "cleanedAt": json["catalogCleanedAt"] as? String ?? "?",
        "rowCount": json["catalogRowCount"] as? String ?? "?"
    ]
    let currentStamp = [
        "version": run.meta["version"] ?? "?",
        "cleanedAt": run.meta["cleaned_at"] ?? "never",
        "rowCount": run.meta["count"] ?? "?"
    ]
    print(ScoreDelta.report(baseline: baselineScores, current: run.scored,
                            baselineStamp: baselineStamp, currentStamp: currentStamp))

case "explain":
    print(Explain.report(catalog: openCatalog(), data: loadDatabase(), gtin: requiredOption("gtin")))

case "doctor":
    exit(Doctor.run(repoRoot: repoRoot) ? 0 : 1)

default:
    print(usage)
    exit(1)
}

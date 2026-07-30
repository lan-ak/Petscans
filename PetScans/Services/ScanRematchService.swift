import Foundation
import SwiftData

/// Re-runs matching and scoring over saved scans after the matcher changes.
///
/// **Deliberately not wired as of 1.4.4 — do not "fix" this by adding a call site.**
/// Its only caller was `AppInitializer`, which was itself never called and has been
/// deleted. Three things have to be true before this runs, and none of them are yet:
///
/// 1. The loop below is `@MainActor` and synchronous — match, score and JSON-encode per
///    scan, measured at ~2.2 ms/product on Apple Silicon and est. 5-7 ms on device. A
///    user with 200 saved scans gets a ~1 s main-thread hang right after first frame.
///    It needs the compute moved off the main actor and the writes chunked.
/// 2. It is a one-way, one-shot rewrite of persisted user data behind the `UserDefaults`
///    key below, and 1.4.4 is a catalog + matcher release — so by construction it *will*
///    move saved verdicts. A scan the owner remembers as "Excellent 88" silently becomes
///    "Caution 62" with no changelog and no rollback.
/// 3. Because the flag persists in the simulator container across `app.terminate()`, a
///    green UI-test run proves nothing about the next one. It needs a deterministic test
///    fixture before it can be trusted.
///
/// Ship it with a human watching, a progress indicator, and something that tells the
/// owner their history was recalculated.
///
/// A `Scan` persists `matchedIngredients` and `scoreBreakdown` as JSON blobs written
/// at scan time; nothing re-derives them when history is displayed. So a tokenizer fix
/// reaches new scans immediately and old ones never — a user who reports a broken
/// ingredient list is looking at exactly the scan that would keep showing it.
/// `rawIngredientText` is persisted too, which is what makes recomputing possible.
///
/// **Scans carrying an allergen flag are left alone.** A `Scan` records no link to the
/// pet it was scored for, so the allergen list that produced that verdict cannot be
/// recovered. Those scans are "Avoid" because something matched the pet's profile, and
/// re-scoring them without that list would quietly turn an Avoid into an Excellent.
/// Leaving them frozen keeps a wrong-but-safe verdict over a wrong-and-unsafe one; the
/// owner gets the corrected reading by rescanning.
///
/// The same gap runs the other way and cannot be closed here: if expansion reveals an
/// allergen that used to be hidden inside a group, a re-scored scan still won't flag it,
/// because there is no allergen list to check against. That is not a regression — the
/// ingredient was equally invisible before — but it is a reason to persist the scored-for
/// pet on `Scan` if this ever needs to be exact.
enum ScanRematchService {
    /// Bumped when a matcher change is significant enough to be worth rewriting history
    /// for. The version is in the key so a future change can run its own pass.
    private static let migrationKey = "hasRematchedScans_v1_groupExpansion"

    @MainActor
    static func rematchIfNeeded(modelContext: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let scans = (try? modelContext.fetch(FetchDescriptor<Scan>())) ?? []
        guard !scans.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let data = await IngredientDatabase.shared.waitForLoad()
        let matcher = IngredientMatcher()
        let calculator = ScoreCalculator()
        let groups = AvoidancePreferences.groups

        for scan in scans {
            guard !scan.rawIngredientText.isEmpty else { continue }

            let previous = scan.scoreBreakdown
            // A breakdown that failed to decode has no flags to inspect and no scores
            // worth preserving, so it is safe — and useful — to rebuild.
            guard !previous.flags.contains(where: { $0.type == .allergen }) else { continue }

            let matched = matcher.match(rawIngredients: scan.rawIngredientText, data: data)
            guard !matched.isEmpty else { continue }

            let breakdown = calculator.calculate(
                species: scan.speciesEnum,
                category: scan.categoryEnum,
                matched: matched,
                data: data,
                avoidanceGroups: groups,
                scoreSource: previous.scoreSource,
                ocrConfidence: previous.ocrConfidence
            )
            scan.replaceAnalysis(matchedIngredients: matched, scoreBreakdown: breakdown)
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}

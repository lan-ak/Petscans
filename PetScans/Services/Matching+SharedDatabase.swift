import Foundation

/// The app-environment glue for matching and scoring: the convenience overloads
/// that reach for the `IngredientDatabase` singleton and wait on its background
/// load.
///
/// These are deliberately kept out of `IngredientMatcher` and `ScoreCalculator`
/// so those two stay pure functions of the `IngredientData` they're handed. The
/// `matchkit` offline harness compiles the matcher and scorer but not this file,
/// which is what guarantees it can't accidentally pick up app state — and what
/// makes its coverage and score-delta numbers trustworthy as predictions of
/// on-device behaviour. Same rule as `Models+UI.swift`: capability here, not in
/// the thing being made capable.

extension IngredientMatcher {
    /// Match against the app's loaded database, waiting for the background load
    /// if it hasn't landed yet.
    func match(rawIngredients: String) async -> [MatchedIngredient] {
        let data = await IngredientDatabase.shared.waitForLoad()
        return match(rawIngredients: rawIngredients, data: data)
    }
}

extension ScoreCalculator {
    /// Score against the app's loaded database.
    ///
    /// `avoidanceGroups` defaults to the device-level selection so every existing
    /// caller (scanner, history) automatically reflects the owner's watch list. The
    /// onboarding AHA passes its in-progress selection explicitly, because the pet
    /// and preferences aren't persisted until onboarding completes.
    func calculate(
        species: Species,
        category: Category,
        matched: [MatchedIngredient],
        petAllergens: [String] = [],
        petName: String? = nil,
        avoidanceGroups: Set<AvoidanceGroup> = AvoidancePreferences.groups,
        scoreSource: ScoreSource = .databaseVerified,
        ocrConfidence: Float? = nil
    ) async -> ScoreBreakdown {
        let data = await IngredientDatabase.shared.waitForLoad()
        return calculate(
            species: species,
            category: category,
            matched: matched,
            data: data,
            petAllergens: petAllergens,
            petName: petName,
            avoidanceGroups: avoidanceGroups,
            scoreSource: scoreSource,
            ocrConfidence: ocrConfidence
        )
    }
}

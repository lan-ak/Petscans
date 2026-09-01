import Foundation

/// Scores a catalog product against the pet profile being assembled during
/// onboarding, without touching SwiftData — the `Pet` isn't persisted until
/// onboarding completes, so the score runs off the in-progress selections.
///
/// This is the same pipeline the scanner uses (`IngredientMatcher` ->
/// `ScoreCalculator`), just called directly instead of through the
/// SwiftData-coupled `ScannerViewModel`.
enum OnboardingFoodScorer {
    struct Result {
        let matched: [MatchedIngredient]
        let breakdown: ScoreBreakdown
    }

    /// - Parameter species: the species to score *as*. Defaults to the product's own, which
    ///   is right for the onboarding demo — there is no pet yet. Once there is one, callers
    ///   pass the pet's species, because that is what `ScannerViewModel` will use for every
    ///   scan afterwards and the two must not disagree about the same food.
    static func score(
        product: CatalogProduct,
        petName: String?,
        allergens: Set<String>,
        groups: Set<AvoidanceGroup>,
        species: Species? = nil,
        matcher: IngredientMatcher = IngredientMatcher(),
        calculator: ScoreCalculator = ScoreCalculator()
    ) async -> Result {
        let matched = await matcher.match(rawIngredients: product.ingredients)
        let breakdown = await calculator.calculate(
            species: species ?? product.species,
            category: product.category,
            matched: matched,
            petAllergens: Array(allergens),
            petName: petName,
            avoidanceGroups: groups,
            scoreSource: .databaseVerified
        )
        return Result(matched: matched, breakdown: breakdown)
    }
}

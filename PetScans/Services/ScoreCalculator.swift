import Foundation

/// Calculates safety, nutrition, and suitability scores for pet products
struct ScoreCalculator {
    // MARK: - Configuration Constants

    // Scoring weights
    private let weightsFoodTreat = (safety: 0.45, nutrition: 0.40, suitability: 0.15)
    private let weightsCosmetic = (safety: 0.70, suitability: 0.30)
    private let rankDecayK = 0.22
    private let criticalCap = 10.0

    // Unknown ingredient penalties
    private static let unknownPenaltyTop5: Double = 3.0
    private static let unknownPenaltyOthers: Double = 1.5

    // Allergen penalties
    private static let allergenPenaltyTop5: Double = 30.0
    private static let allergenPenaltyOthers: Double = 15.0

    // Nutrition bonuses and penalties
    private static let proteinBonusTop3: Double = 4.0
    private static let artificialColorsPenalty: Double = -6.0
    private static let preservativesPenalty: Double = -5.0

    // Protein sources for nutrition scoring
    private static let proteinSources = [
        "chicken", "beef", "turkey", "lamb", "pork", "salmon",
        "tuna", "whitefish", "egg", "liver", "heart"
    ]

    // Harmful preservatives
    private static let harmfulPreservatives = ["bha", "bht", "ethoxyquin"]

    let ingredients: [String: Ingredient]
    let rules: [Rule]

    init(
        ingredients: [String: Ingredient] = IngredientDatabase.shared.ingredients,
        rules: [Rule] = IngredientDatabase.shared.rules
    ) {
        self.ingredients = ingredients
        self.rules = rules
    }

    /// Calculate scores for a product
    func calculate(
        species: Species,
        category: Category,
        matched: [MatchedIngredient],
        petAllergens: [String] = [],
        scoreSource: ScoreSource = .databaseVerified,
        ocrConfidence: Float? = nil
    ) -> ScoreBreakdown {
        let normalizedAllergens = normalizeAllergens(petAllergens)

        // Process each aspect separately
        let (safetyPenalty, unmatched) = processIngredientSafety(matched: matched)
        let (suitability, allergenFlags) = checkAllergenSuitability(
            matched: matched,
            allergens: normalizedAllergens
        )
        let nutrition = calculateNutritionHeuristics(matched: matched, category: category)
        let (rulePenalty, ruleFlags, sawCritical) = processRules(
            matched: matched,
            species: species,
            category: category
        )

        // Combine results
        let totalSafetyPenalty = safetyPenalty + rulePenalty
        let allFlags = allergenFlags + ruleFlags

        // Calculate final scores
        let (total, safety, finalNutrition, finalSuitability) = calculateFinalScores(
            safetyPenalty: totalSafetyPenalty,
            nutrition: nutrition,
            suitability: suitability,
            category: category,
            sawCritical: sawCritical
        )

        let matchedCount = matched.count - unmatched.count
        let totalCount = matched.count

        return ScoreBreakdown(
            total: round(total * 10) / 10,
            safety: round(safety * 10) / 10,
            nutrition: finalNutrition != nil ? round(finalNutrition! * 10) / 10 : nil,
            suitability: round(finalSuitability * 10) / 10,
            flags: allFlags,
            unmatched: unmatched,
            matchedCount: matchedCount,
            totalCount: totalCount,
            scoreSource: scoreSource,
            ocrConfidence: ocrConfidence
        )
    }

    // MARK: - Private Helper Methods

    /// Normalize allergen strings for comparison
    private func normalizeAllergens(_ allergens: [String]) -> [String] {
        allergens.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
    }

    /// Process ingredient safety and return penalty and unmatched ingredients
    private func processIngredientSafety(
        matched: [MatchedIngredient]
    ) -> (penalty: Double, unmatched: [String]) {
        var safetyPenalty = 0.0
        var unmatched: [String] = []

        for mi in matched {
            let weight = rankWeight(mi.rank)

            // Check if ingredient is matched in database
            guard let ingredientId = mi.ingredientId,
                  let ing = ingredients[ingredientId] else {
                unmatched.append(mi.labelName)
                // Higher penalty for unknown ingredients in top positions
                let unknownPenalty = mi.rank <= 5 ?
                    Self.unknownPenaltyTop5 : Self.unknownPenaltyOthers
                safetyPenalty += unknownPenalty * weight
                continue
            }

            // Add safety penalty based on ingredient risk level
            safetyPenalty += basePenalty(for: ing.riskLevel) * weight
        }

        return (safetyPenalty, unmatched)
    }

    /// Check for allergen conflicts and return suitability score and flags
    private func checkAllergenSuitability(
        matched: [MatchedIngredient],
        allergens: [String]
    ) -> (suitability: Double, flags: [WarningFlag]) {
        var suitability = 100.0
        var flags: [WarningFlag] = []

        for mi in matched {
            guard let ingredientId = mi.ingredientId,
                  let ing = ingredients[ingredientId] else {
                continue
            }

            let ingNameNorm = ing.commonName.lowercased()

            for allergen in allergens {
                if !allergen.isEmpty && (ingNameNorm == allergen || ingNameNorm.contains(allergen)) {
                    // Higher penalty for allergens in top positions
                    let penalty = mi.rank <= 5 ?
                        Self.allergenPenaltyTop5 : Self.allergenPenaltyOthers
                    suitability -= penalty

                    flags.append(WarningFlag(
                        severity: .high,
                        title: "Possible allergen",
                        explain: "\(ing.commonName) may conflict with your pet's allergen profile.",
                        ingredientId: ing.id
                    ))
                }
            }
        }

        return (suitability, flags)
    }

    /// Calculate nutrition score based on ingredient heuristics
    private func calculateNutritionHeuristics(
        matched: [MatchedIngredient],
        category: Category
    ) -> Double {
        // Only apply nutrition scoring to food and treats
        guard category == .food || category == .treat else {
            return 100.0
        }

        var nutrition = 100.0

        for mi in matched {
            guard let ingredientId = mi.ingredientId,
                  let ing = ingredients[ingredientId] else {
                continue
            }

            let ingNameNorm = ing.commonName.lowercased()
            let fn = (ing.typicalFunction ?? "").lowercased()

            // Bonus for protein sources in top 3 positions
            let isProteinLike = fn.contains("protein") ||
                Self.proteinSources.contains { ingNameNorm.contains($0) }

            if isProteinLike && mi.rank <= 3 {
                nutrition += Self.proteinBonusTop3
            }

            // Penalties for artificial additives
            if ingNameNorm.contains("artificial colors") {
                nutrition += Self.artificialColorsPenalty
            }

            if Self.harmfulPreservatives.contains(where: { ingNameNorm.contains($0) }) {
                nutrition += Self.preservativesPenalty
            }
        }

        return nutrition
    }

    /// Process safety rules and return penalty, flags, and critical flag indicator
    private func processRules(
        matched: [MatchedIngredient],
        species: Species,
        category: Category
    ) -> (penalty: Double, flags: [WarningFlag], sawCritical: Bool) {
        var rulePenalty = 0.0
        var flags: [WarningFlag] = []
        var sawCritical = false

        for mi in matched {
            guard let ingredientId = mi.ingredientId,
                  let ing = ingredients[ingredientId] else {
                continue
            }

            let weight = rankWeight(mi.rank)

            // Find applicable rules for this ingredient
            for rule in rules {
                guard rule.ingredientId == ing.id,
                      rule.appliesTo.species.contains(species),
                      rule.appliesTo.categories.contains(category) else {
                    continue
                }

                // Track if we've seen a critical rule
                if rule.severity == .critical {
                    sawCritical = true
                }

                flags.append(WarningFlag(
                    severity: rule.severity,
                    title: "Ingredient rule triggered",
                    explain: rule.explain,
                    ingredientId: ing.id
                ))

                rulePenalty += Double(abs(rule.scoreImpact)) * weight
            }
        }

        return (rulePenalty, flags, sawCritical)
    }

    /// Calculate final weighted scores and apply caps
    private func calculateFinalScores(
        safetyPenalty: Double,
        nutrition: Double,
        suitability: Double,
        category: Category,
        sawCritical: Bool
    ) -> (total: Double, safety: Double, nutrition: Double?, suitability: Double) {
        // Clamp individual scores to 0-100 range
        let safety = max(0, min(100, 100 - safetyPenalty))
        let clampedSuitability = max(0, min(100, suitability))
        let clampedNutrition = max(0, min(100, nutrition))

        // Calculate weighted total based on category
        var total: Double
        if category == .cosmetic {
            total = weightsCosmetic.safety * safety +
                    weightsCosmetic.suitability * clampedSuitability
        } else {
            total = weightsFoodTreat.safety * safety +
                    weightsFoodTreat.nutrition * clampedNutrition +
                    weightsFoodTreat.suitability * clampedSuitability
        }

        // Cap total score if critical rule was triggered
        if sawCritical {
            total = min(total, criticalCap)
        }

        // Return nutrition as nil for cosmetics
        let finalNutrition = category == .cosmetic ? nil : clampedNutrition

        return (total, safety, finalNutrition, clampedSuitability)
    }

    /// Exponential rank weight decay
    private func rankWeight(_ rank: Int) -> Double {
        exp(-rankDecayK * Double(rank - 1))
    }

    /// Base penalty for risk level
    private func basePenalty(for riskLevel: String) -> Double {
        let r = riskLevel.lowercased()
        if r.contains("toxic") { return 40 }
        if r.contains("caution") { return 15 }
        if r.contains("moderation") { return 6 }
        if r.contains("safe_for_most") { return 2 }
        return 0
    }
}

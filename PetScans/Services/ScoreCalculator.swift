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

    private let database = IngredientDatabase.shared

    init() {}

    /// Calculate scores for a product
    func calculate(
        species: Species,
        category: Category,
        matched: [MatchedIngredient],
        petAllergens: [String] = [],
        petName: String? = nil,
        scoreSource: ScoreSource = .databaseVerified,
        ocrConfidence: Float? = nil
    ) async -> ScoreBreakdown {
        await database.waitForLoad()
        let ingredients = database.ingredients
        let rules = database.rules

        let normalizedAllergens = normalizeAllergens(petAllergens)

        // Process each aspect separately
        let (safetyPenalty, unmatched, safetyFactors) = processIngredientSafety(matched: matched, species: species, ingredients: ingredients)
        let (suitability, allergenFlags, suitabilityFactors) = checkAllergenSuitability(
            matched: matched,
            allergens: normalizedAllergens,
            petName: petName,
            ingredients: ingredients
        )
        let nutrition = calculateNutritionHeuristics(matched: matched, category: category, ingredients: ingredients)
        let (rulePenalty, ruleFlags, sawCritical, ruleFactors) = processRules(
            matched: matched,
            species: species,
            category: category,
            ingredients: ingredients,
            rules: rules
        )

        // Combine results
        let totalSafetyPenalty = safetyPenalty + rulePenalty
        let allFlags = allergenFlags + ruleFlags
        let allSafetyFactors = safetyFactors + ruleFactors

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

        // Generate explanations
        let safetyExplanation = generateSafetyExplanation(
            factors: allSafetyFactors
        )
        let suitabilityExplanation = generateSuitabilityExplanation(
            factors: suitabilityFactors,
            petName: petName
        )

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
            ocrConfidence: ocrConfidence,
            safetyExplanation: safetyExplanation,
            suitabilityExplanation: suitabilityExplanation
        )
    }

    // MARK: - Private Helper Methods

    /// Normalize allergen strings for comparison
    private func normalizeAllergens(_ allergens: [String]) -> [String] {
        allergens.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
    }

    /// Process ingredient safety and return penalty, unmatched ingredients, and explanation factors
    private func processIngredientSafety(
        matched: [MatchedIngredient],
        species: Species,
        ingredients: [String: Ingredient]
    ) -> (penalty: Double, unmatched: [String], factors: [ExplanationFactor]) {
        var safetyPenalty = 0.0
        var unmatched: [String] = []
        var factors: [ExplanationFactor] = []

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

                factors.append(ExplanationFactor(
                    id: "unknown-\(mi.labelName)",
                    description: "Unknown ingredient - not in database",
                    impact: .negative,
                    ingredientName: mi.labelName
                ))
                continue
            }

            // Add safety penalty based on ingredient risk level
            let penalty = basePenalty(for: ing.riskLevel)
            safetyPenalty += penalty * weight

            // Add explanation factor for concerning ingredients
            let riskLevel = ing.riskLevel.lowercased()
            if riskLevel.contains("toxic") {
                factors.append(ExplanationFactor(
                    id: ing.id,
                    description: "Toxic to \(species.displayName)s",
                    impact: .negative,
                    ingredientName: ing.commonName
                ))
            } else if riskLevel.contains("caution") {
                factors.append(ExplanationFactor(
                    id: ing.id,
                    description: "Use with caution",
                    impact: .negative,
                    ingredientName: ing.commonName
                ))
            } else if riskLevel.contains("safe") && mi.rank <= 3 {
                factors.append(ExplanationFactor(
                    id: ing.id,
                    description: "Safe ingredient",
                    impact: .positive,
                    ingredientName: ing.commonName
                ))
            }
        }

        return (safetyPenalty, unmatched, factors)
    }

    /// Check for allergen conflicts and return suitability score, flags, and explanation factors
    private func checkAllergenSuitability(
        matched: [MatchedIngredient],
        allergens: [String],
        petName: String?,
        ingredients: [String: Ingredient]
    ) -> (suitability: Double, flags: [WarningFlag], factors: [ExplanationFactor]) {
        var suitability = 100.0
        var flags: [WarningFlag] = []
        var factors: [ExplanationFactor] = []
        let petDisplayName = petName ?? "your pet"

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
                        explain: "\(ing.commonName) may conflict with \(petDisplayName)'s allergen profile.",
                        ingredientId: ing.id,
                        source: nil,
                        type: .allergen
                    ))

                    factors.append(ExplanationFactor(
                        id: "allergen-\(ing.id)",
                        description: "Matches \(petDisplayName)'s allergen profile",
                        impact: .negative,
                        ingredientName: ing.commonName
                    ))
                }
            }
        }

        // Add positive factor if no allergens found
        if factors.isEmpty && !allergens.isEmpty {
            factors.append(ExplanationFactor(
                id: "no-allergens",
                description: "No known allergens for \(petDisplayName)",
                impact: .positive,
                ingredientName: nil
            ))
        }

        return (suitability, flags, factors)
    }

    /// Calculate nutrition score based on ingredient heuristics
    private func calculateNutritionHeuristics(
        matched: [MatchedIngredient],
        category: Category,
        ingredients: [String: Ingredient]
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

    /// Process safety rules and return penalty, flags, critical indicator, and explanation factors
    private func processRules(
        matched: [MatchedIngredient],
        species: Species,
        category: Category,
        ingredients: [String: Ingredient],
        rules: [Rule]
    ) -> (penalty: Double, flags: [WarningFlag], sawCritical: Bool, factors: [ExplanationFactor]) {
        var rulePenalty = 0.0
        var flags: [WarningFlag] = []
        var sawCritical = false
        var factors: [ExplanationFactor] = []

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
                    title: rule.severity == .critical ? "Critical warning" : "Ingredient warning",
                    explain: rule.explain,
                    ingredientId: ing.id,
                    source: rule.source,
                    type: .safety
                ))

                factors.append(ExplanationFactor(
                    id: "rule-\(rule.id)",
                    description: rule.explain,
                    impact: .negative,
                    ingredientName: ing.commonName
                ))

                rulePenalty += Double(abs(rule.scoreImpact)) * weight
            }
        }

        return (rulePenalty, flags, sawCritical, factors)
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

    // MARK: - Explanation Generation

    /// Generate safety score explanation
    private func generateSafetyExplanation(
        factors: [ExplanationFactor]
    ) -> ScoreExplanation {
        let negativeCount = factors.filter { $0.impact == .negative }.count
        let summary: String

        if negativeCount == 0 {
            summary = "All ingredients appear safe."
        } else if negativeCount == 1 {
            summary = "One ingredient requires attention."
        } else {
            summary = "\(negativeCount) ingredients require attention."
        }

        // Limit factors to most important ones (max 5)
        let limitedFactors = Array(factors.prefix(5))

        return ScoreExplanation(factors: limitedFactors, summary: summary)
    }

    /// Generate suitability score explanation
    private func generateSuitabilityExplanation(
        factors: [ExplanationFactor],
        petName: String?
    ) -> ScoreExplanation {
        let petDisplayName = petName ?? "your pet"
        let allergenCount = factors.filter { $0.impact == .negative }.count
        let summary: String

        if allergenCount == 0 {
            summary = "No known allergens detected for \(petDisplayName)."
        } else if allergenCount == 1 {
            summary = "Contains 1 potential allergen for \(petDisplayName)."
        } else {
            summary = "Contains \(allergenCount) potential allergens for \(petDisplayName)."
        }

        return ScoreExplanation(factors: factors, summary: summary)
    }
}

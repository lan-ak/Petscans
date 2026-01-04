import Foundation

/// Calculates safety, suitability, and processing scores for pet products
struct ScoreCalculator {
    // MARK: - Configuration Constants

    // Scoring weights (when no allergen match)
    // If allergen match exists, total score is 0 regardless of weights
    private let weightsFoodTreat = (safety: 0.50, processing: 0.50)
    private let weightsCosmetic = (safety: 0.60, processing: 0.40)
    private let rankDecayK = 0.22
    private let criticalCap = 10.0

    // Unknown ingredient penalties
    private static let unknownPenaltyTop5: Double = 3.0
    private static let unknownPenaltyOthers: Double = 1.5

    // Allergen penalties (for suitability score display, but any match = total 0)
    private static let allergenPenaltyTop5: Double = 30.0
    private static let allergenPenaltyOthers: Double = 15.0

    // Processing level penalties (higher = more processed = lower score)
    private static let processingPenalties: [ProcessingLevel: Double] = [
        .unprocessed: 0,
        .culinaryIngredient: 3,
        .processed: 8,
        .ultraProcessed: 15
    ]

    private var database: IngredientDatabase { IngredientDatabase.shared }

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
        let (safetyPenalty, unmatched, safetyFactors, hasToxic, hasCaution) = processIngredientSafety(matched: matched, species: species, ingredients: ingredients)
        let (suitability, allergenFlags, suitabilityFactors) = checkAllergenSuitability(
            matched: matched,
            allergens: normalizedAllergens,
            petName: petName,
            ingredients: ingredients
        )
        let (processing, processingFactors) = calculateProcessingScore(matched: matched)
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

        // CRITICAL: Any allergen match = score 0, rating "Avoid"
        let hasAllergenMatch = !allergenFlags.isEmpty

        // Calculate final scores
        let (total, safety, finalProcessing, finalSuitability) = calculateFinalScores(
            safetyPenalty: totalSafetyPenalty,
            processing: processing,
            suitability: suitability,
            category: category,
            sawCritical: sawCritical,
            hasAllergenMatch: hasAllergenMatch
        )

        let matchedCount = matched.count - unmatched.count
        let totalCount = matched.count

        // Generate explanations
        let safetyExplanation = generateSafetyExplanation(
            factors: allSafetyFactors,
            hasToxic: hasToxic,
            hasCaution: hasCaution
        )
        let suitabilityExplanation = generateSuitabilityExplanation(
            factors: suitabilityFactors,
            petName: petName,
            hasAllergenMatch: hasAllergenMatch,
            hasToxic: hasToxic
        )
        let processingExplanation = generateProcessingExplanation(
            factors: processingFactors
        )

        return ScoreBreakdown(
            total: round(total * 10) / 10,
            safety: round(safety * 10) / 10,
            suitability: round(finalSuitability * 10) / 10,
            processing: finalProcessing != nil ? round(finalProcessing! * 10) / 10 : nil,
            flags: allFlags,
            unmatched: unmatched,
            matchedCount: matchedCount,
            totalCount: totalCount,
            scoreSource: scoreSource,
            ocrConfidence: ocrConfidence,
            safetyExplanation: safetyExplanation,
            suitabilityExplanation: suitabilityExplanation,
            processingExplanation: processingExplanation
        )
    }

    // MARK: - Private Helper Methods

    /// Normalize allergen strings for comparison
    private func normalizeAllergens(_ allergens: [String]) -> [String] {
        allergens.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
    }

    /// Process ingredient safety and return penalty, unmatched ingredients, explanation factors, and risk flags
    private func processIngredientSafety(
        matched: [MatchedIngredient],
        species: Species,
        ingredients: [String: Ingredient]
    ) -> (penalty: Double, unmatched: [String], factors: [ExplanationFactor], hasToxic: Bool, hasCaution: Bool) {
        var safetyPenalty = 0.0
        var unmatched: [String] = []
        var factors: [ExplanationFactor] = []
        var hasToxic = false
        var hasCaution = false

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
                hasToxic = true
                factors.append(ExplanationFactor(
                    id: ing.id,
                    description: "Toxic to \(species.displayName)s",
                    impact: .negative,
                    ingredientName: ing.commonName
                ))
            } else if riskLevel.contains("caution") {
                hasCaution = true
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

        return (safetyPenalty, unmatched, factors, hasToxic, hasCaution)
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

    /// Calculate processing score based on NOVA-style classification
    private func calculateProcessingScore(
        matched: [MatchedIngredient]
    ) -> (score: Double, factors: [ExplanationFactor]) {
        var penalty = 0.0
        var factors: [ExplanationFactor] = []
        var classifiedCount = 0

        for mi in matched {
            guard let level = mi.processingLevel else { continue }
            classifiedCount += 1

            let weight = rankWeight(mi.rank)
            penalty += Self.processingPenalties[level, default: 0] * weight

            if level == .ultraProcessed {
                factors.append(ExplanationFactor(
                    id: "processing-\(mi.labelName)",
                    description: "Ultra-processed ingredient",
                    impact: .negative,
                    ingredientName: mi.labelName
                ))
            } else if level == .processed {
                factors.append(ExplanationFactor(
                    id: "processing-\(mi.labelName)",
                    description: "Processed ingredient",
                    impact: .negative,
                    ingredientName: mi.labelName
                ))
            }
        }

        // Add positive factor if mostly minimally processed
        let unprocessedCount = matched.filter { $0.processingLevel == .unprocessed }.count
        if unprocessedCount > matched.count / 2 && matched.count > 0 {
            factors.insert(ExplanationFactor(
                id: "processing-positive",
                description: "Majority minimally processed",
                impact: .positive,
                ingredientName: nil
            ), at: 0)
        }

        // Handle case where processing data is limited
        let classificationRate = matched.count > 0 ? Double(classifiedCount) / Double(matched.count) : 0
        if classificationRate < 0.5 && matched.count > 0 {
            return (80.0, [ExplanationFactor(
                id: "processing-incomplete",
                description: "Limited processing data available",
                impact: .neutral,
                ingredientName: nil
            )])
        }

        return (max(0, min(100, 100 - penalty)), factors)
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
        processing: Double,
        suitability: Double,
        category: Category,
        sawCritical: Bool,
        hasAllergenMatch: Bool
    ) -> (total: Double, safety: Double, processing: Double?, suitability: Double) {
        // Clamp individual scores to 0-100 range
        let safety = max(0, min(100, 100 - safetyPenalty))
        let clampedSuitability = max(0, min(100, suitability))
        let clampedProcessing = max(0, min(100, processing))

        // CRITICAL: Any allergen match = total score 0, always "Avoid"
        if hasAllergenMatch {
            return (0, safety, clampedProcessing, 0)
        }

        // Calculate weighted total based on category
        var total: Double
        if category == .cosmetic {
            total = weightsCosmetic.safety * safety +
                    weightsCosmetic.processing * clampedProcessing
        } else {
            total = weightsFoodTreat.safety * safety +
                    weightsFoodTreat.processing * clampedProcessing
        }

        // Cap total score if critical rule was triggered
        if sawCritical {
            total = min(total, criticalCap)
        }

        return (total, safety, clampedProcessing, clampedSuitability)
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
        factors: [ExplanationFactor],
        hasToxic: Bool,
        hasCaution: Bool
    ) -> ScoreExplanation {
        let negativeCount = factors.filter { $0.impact == .negative }.count
        let summary: String

        if hasToxic {
            summary = "Contains toxic ingredient(s) - not safe for pets."
        } else if negativeCount == 0 {
            summary = "All ingredients appear safe."
        } else if negativeCount == 1 {
            summary = "One ingredient requires attention."
        } else {
            summary = "\(negativeCount) ingredients require attention."
        }

        // Limit factors to most important ones (max 5)
        let limitedFactors = Array(factors.prefix(5))

        // Determine label override based on risk level
        let labelOverride: RatingLabel?
        if hasToxic {
            labelOverride = .avoid
        } else if hasCaution {
            labelOverride = .caution
        } else {
            labelOverride = nil
        }

        return ScoreExplanation(factors: limitedFactors, summary: summary, labelOverride: labelOverride)
    }

    /// Generate suitability score explanation
    private func generateSuitabilityExplanation(
        factors: [ExplanationFactor],
        petName: String?,
        hasAllergenMatch: Bool,
        hasToxic: Bool
    ) -> ScoreExplanation {
        let petDisplayName = petName ?? "your pet"
        let allergenCount = factors.filter { $0.impact == .negative }.count
        let summary: String

        // Toxic ingredients make the product unsuitable regardless of allergens
        if hasToxic {
            summary = "Contains toxic ingredient(s) - not suitable for \(petDisplayName)."
        } else if hasAllergenMatch {
            if allergenCount == 1 {
                summary = "Contains an ingredient \(petDisplayName) should avoid. Score set to Avoid."
            } else {
                summary = "Contains \(allergenCount) ingredients \(petDisplayName) should avoid. Score set to Avoid."
            }
        } else if allergenCount == 0 {
            summary = "No known allergens detected for \(petDisplayName)."
        } else if allergenCount == 1 {
            summary = "Contains 1 potential allergen for \(petDisplayName)."
        } else {
            summary = "Contains \(allergenCount) potential allergens for \(petDisplayName)."
        }

        // If toxic or has allergen match, override label to Avoid
        let labelOverride: RatingLabel? = (hasToxic || hasAllergenMatch) ? .avoid : nil

        return ScoreExplanation(factors: factors, summary: summary, labelOverride: labelOverride)
    }

    /// Generate processing score explanation
    private func generateProcessingExplanation(
        factors: [ExplanationFactor]
    ) -> ScoreExplanation {
        let negativeCount = factors.filter { $0.impact == .negative }.count
        let hasPositive = factors.contains { $0.impact == .positive }
        let summary: String

        if factors.first?.id == "processing-incomplete" {
            summary = "Limited processing data available for analysis."
        } else if hasPositive && negativeCount == 0 {
            summary = "Mostly minimally processed ingredients."
        } else if negativeCount == 0 {
            summary = "Good processing profile."
        } else if negativeCount <= 2 {
            summary = "Some processed ingredients detected."
        } else {
            summary = "Several processed or ultra-processed ingredients."
        }

        // Limit factors to most important ones (max 5)
        let limitedFactors = Array(factors.prefix(5))

        return ScoreExplanation(factors: limitedFactors, summary: summary)
    }
}

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

    // Avoidance-group penalties. Owner-selected groups are a soft signal: they lower
    // the total (enough to nudge the rating label down a tier or two) and raise a
    // warning flag, but never force "Avoid" — only allergens/toxics do that.
    private static let avoidanceGroupPenaltyTop5: Double = 8.0
    private static let avoidanceGroupPenaltyOthers: Double = 4.0
    private static let avoidanceGroupPenaltyCap: Double = 40.0

    // Processing level penalties (higher = more processed = lower score)
    private static let processingPenalties: [ProcessingLevel: Double] = [
        .unprocessed: 0,
        .culinaryIngredient: 3,
        .processed: 8,
        .ultraProcessed: 15
    ]

    init() {}

    /// Score against a given database. Synchronous and pure — the entry point
    /// tests and the `matchkit` score-delta audit use, so an offline before/after
    /// comparison exercises exactly the scoring the app will perform.
    func calculate(
        species: Species,
        category: Category,
        matched: [MatchedIngredient],
        data: IngredientData,
        petAllergens: [String] = [],
        petName: String? = nil,
        // Deliberately no default. The async overload in `Matching+SharedDatabase`
        // defaults this to `AvoidancePreferences.groups`; if this one defaulted to
        // `[]`, dropping an `await` at a call site would silently stop applying the
        // owner's watch list and nothing would fail. Callers must say what they mean.
        avoidanceGroups: Set<AvoidanceGroup>,
        scoreSource: ScoreSource = .databaseVerified,
        ocrConfidence: Float? = nil
    ) -> ScoreBreakdown {
        let ingredients = data.ingredients
        let rules = data.rules
        let groupMap = data.avoidanceGroups

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
        let (groupPenalty, groupFlags, _) = checkAvoidanceGroups(
            matched: matched,
            selectedGroups: avoidanceGroups,
            ingredients: ingredients,
            groupMap: groupMap
        )

        // Combine results
        let totalSafetyPenalty = safetyPenalty + rulePenalty
        let allFlags = allergenFlags + ruleFlags + groupFlags
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
            hasAllergenMatch: hasAllergenMatch,
            avoidanceGroupPenalty: groupPenalty
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

            // Add safety penalty based on species-specific risk level
            let riskLevelForSpecies = ing.riskLevel(for: species)
            let penalty = basePenalty(for: riskLevelForSpecies)
            safetyPenalty += penalty * weight

            // Add explanation factor for concerning ingredients
            let riskLevel = riskLevelForSpecies.lowercased()
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

            for allergen in allergens where AllergenFamily.matches(allergen: allergen, ingredient: ing) {
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

                // One ingredient, one flag. Families overlap at the edges (a fish oil is
                // both "fish" and, for some owners, a named species), and without this the
                // same row was listed twice and penalised twice.
                break
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

    /// Flag ingredients that fall into an owner-selected avoidance group.
    ///
    /// Warning-only: returns a bounded penalty and `.warn` flags. It sets no label
    /// override, so it can pull the numeric rating down a tier but never forces
    /// "Avoid" the way an allergen or toxic ingredient does.
    private func checkAvoidanceGroups(
        matched: [MatchedIngredient],
        selectedGroups: Set<AvoidanceGroup>,
        ingredients: [String: Ingredient],
        groupMap: [String: Set<AvoidanceGroup>]
    ) -> (penalty: Double, flags: [WarningFlag], factors: [ExplanationFactor]) {
        guard !selectedGroups.isEmpty else { return (0, [], []) }

        var penalty = 0.0
        var flags: [WarningFlag] = []
        var factors: [ExplanationFactor] = []

        for mi in matched {
            guard let ingredientId = mi.ingredientId,
                  let ing = ingredients[ingredientId],
                  let ingredientGroups = groupMap[ingredientId] else {
                continue
            }

            let hit = ingredientGroups.intersection(selectedGroups)
            guard !hit.isEmpty else { continue }

            let weight = rankWeight(mi.rank)
            penalty += (mi.rank <= 5 ?
                Self.avoidanceGroupPenaltyTop5 : Self.avoidanceGroupPenaltyOthers) * weight

            // Stable, human-readable list of the matched groups, in enum case order.
            let groupNames = AvoidanceGroup.allCases
                .filter(hit.contains)
                .map(\.displayName)
                .joined(separator: ", ")

            flags.append(WarningFlag(
                severity: .warn,
                title: "On your avoid list",
                explain: "\(ing.commonName) matches a group you chose to avoid: \(groupNames).",
                ingredientId: ing.id,
                source: nil,
                type: .avoidanceGroup
            ))

            factors.append(ExplanationFactor(
                id: "avoidgroup-\(ing.id)",
                description: "Matches your avoid list: \(groupNames)",
                impact: .negative,
                ingredientName: ing.commonName
            ))
        }

        return (min(penalty, Self.avoidanceGroupPenaltyCap), flags, factors)
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
        hasAllergenMatch: Bool,
        avoidanceGroupPenalty: Double
    ) -> (total: Double, safety: Double, processing: Double?, suitability: Double) {
        // Clamp individual scores to 0-100 range
        let safety = max(0, min(100, 100 - safetyPenalty))
        let clampedSuitability = max(0, min(100, suitability))
        let clampedProcessing = max(0, min(100, processing))

        // CRITICAL: Any allergen match = total score 0, always "Avoid". Avoidance-group
        // penalties are irrelevant here — the score is already at the floor.
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

        // Apply the owner's avoidance-group penalty last, as a soft nudge that can
        // lower the rating but not drive it to a forced "Avoid".
        total = max(0, total - avoidanceGroupPenalty)

        return (total, safety, clampedProcessing, clampedSuitability)
    }

    /// Exponential rank weight decay
    private func rankWeight(_ rank: Int) -> Double {
        exp(-rankDecayK * Double(rank - 1))
    }

    /// Base penalty for risk level
    /// Delegates to `RiskTier`, the single classification the row indicators and
    /// the detail sheet also use — so a warning triangle on a row can never
    /// disagree with the penalty behind the score.
    private func basePenalty(for riskLevel: String) -> Double {
        RiskTier(riskLevel).basePenalty
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

/// Ingredient families for the quick-pick allergens.
///
/// **Adding ingredients or expanding the catalog? Follow `docs/catalog-expansion.md`.**
/// `DataValidationTests` fails and names the ingredient if this table drifts from
/// `ingredients.json`, but it cannot see a family member that was never added to the
/// database at all — that is what step 5 of the doc is for.
///
/// The allergen check was a plain substring test on the ingredient's display name, and it
/// failed in both directions:
///
/// - **It missed whole families silently.** No ingredient is named "dairy", so the Dairy
///   chip matched *nothing* — a dairy-allergic pet was told "No known allergens detected"
///   over a food containing Dried whey. Fish was nearly as bad: of 43 fish ingredients only
///   14 carry "fish" in the name, so Salmon, Tuna, Cod, Herring, Sardine, Anchovy, Mackerel,
///   Trout, Krill, Pollock and Tilapia were all invisible to a fish allergy.
/// - **It fired on words that merely contain the allergen.** "wheat" matched **Buckwheat**,
///   a gluten-free seed that is not a wheat, and "corn" matched **Acorn squash**.
///
/// Membership is by ingredient id, so it cannot drift when a display name is edited.
/// Generated from `ingredients.json`. Anything not listed still falls back to a whole-word
/// match on the name, so a later "Chicken thigh" is caught without touching this table.
///
/// Four deliberate calls:
/// - **Shellfish is not fish.** Clam, Crab, Lobster, Mussel, Shrimp and Squid are left out
///   of the fish family: shellfish allergy is a different allergen (tropomyosin, not the
///   parvalbumin of finned fish) and cross-reactivity is low, so folding them in would
///   over-flag the owner who picked "Fish". **Krill is shellfish too** — a crustacean, not
///   a fish — and was caught by the generating regex before this rule was written down.
/// - **Bison is not beef.** It is the novel protein owners are most often switched *to* for
///   a beef allergy; flagging it would condemn the food they were told to buy.
/// - **Refined fish oils count as fish.** Salmon oil, menhaden oil and cod liver oil stay in
///   the family, so a declared fish allergy forces "Avoid" on them. This is the widest call
///   here and was made deliberately: measured over the catalog it means **52.7% of cat foods
///   fail the Fish chip** (40.9% name a fish outright, a further 11.8% only ever name a
///   species oil). Refining removes most of the parvalbumin, so this over-warns — but
///   veterinary elimination diets exclude fish oil when fish is the suspected allergen, and
///   an allergen match is all-or-nothing here: there is no warn-only tier, so the
///   alternative is silence. Revisit this if a warn-only allergen flag is ever added.
/// - **Other refined derivatives follow the same rule, and cost almost nothing.** Soy
///   lecithin, soybean oil and corn oil stay in their families for consistency with the
///   call above. Unlike fish oil the practical impact is negligible: measured over the
///   catalog, soy lecithin and soybean oil appear in **0** products that do not already
///   carry another soy signal, and corn oil alone accounts for **27** products (0.1%). They
///   change almost no verdicts — the fish-oil decision is the only wide one here.
/// - **Poultry counts as chicken.** "Poultry by-product meal" and "Poultry fat" may be
///   turkey, but they are overwhelmingly chicken and the owner has explicitly declared the
///   allergy. In a safety app an over-warning is the cheaper error.
/// - **Spelt counts as wheat** (it is a wheat species and shares the gluten), while
///   buckwheat does not.
enum AllergenFamily {
    static let ingredientIds: [String: Set<String>] = [
        "beef": [
            "ing_beef",
            "ing_beef_by_products",
            "ing_beef_digest",
            "ing_beef_fat",
            "ing_beef_fresh",
            "ing_beef_heart",
            "ing_beef_kidney",
            "ing_beef_liver",
            "ing_beef_lung",
            "ing_beef_meal",
            "ing_beef_tallow",
            "ing_beef_tripe"
        ],
        "chicken": [
            "ing_chicken",
            "ing_chicken_by_product_meal",
            "ing_chicken_by_products",
            "ing_chicken_digest",
            "ing_chicken_fat",
            "ing_chicken_fresh",
            "ing_chicken_gizzard",
            "ing_chicken_heart",
            "ing_chicken_liver",
            "ing_chicken_meal",
            "ing_hydrolyzed_chicken",
            "ing_hydrolyzed_poultry_protein",
            "ing_poultry_by_product_meal",
            "ing_poultry",
            "ing_poultry_by_products",
            "ing_poultry_digest",
            "ing_poultry_fat",
            "ing_poultry_meal"
        ],
        "corn": [
            "ing_corn",
            "ing_corn_bran",
            "ing_corn_flour",
            "ing_corn_germ_meal",
            "ing_corn_gluten_meal",
            "ing_corn_meal",
            "ing_corn_oil",
            "ing_corn_starch",
            "ing_cornstarch"
        ],
        "dairy": [
            "ing_buttermilk",
            "ing_casein",
            "ing_cheese",
            "ing_cheese_powder",
            "ing_cottage_cheese",
            "ing_cream",
            "ing_dried_buttermilk",
            "ing_dried_casein",
            "ing_dried_goat_milk",
            "ing_dried_milk",
            "ing_dried_skim_milk",
            "ing_dried_whey",
            "ing_butter",
            "ing_dried_yogurt",
            "ing_milk",
            "ing_goat_milk",
            "ing_kefir",
            "ing_lactose",
            "ing_milk_protein",
            "ing_skim_milk",
            "ing_whey",
            "ing_whey_protein_concentrate",
            "ing_whey_protein_isolate",
            "ing_whole_milk",
            "ing_yogurt"
        ],
        "fish": [
            "ing_anchovy",
            "ing_anchovy_meal",
            "ing_anchovy_oil",
            "ing_catfish",
            "ing_cod",
            "ing_cod_liver_oil",
            "ing_cod_meal",
            "ing_fish_digest",
            "ing_fish",
            "ing_haddock",
            "ing_fish_meal",
            "ing_fish_oil",
            "ing_fish_protein_concentrate",
            "ing_herring",
            "ing_herring_meal",
            "ing_herring_oil",
            "ing_hydrolyzed_fish_protein",
            "ing_hydrolyzed_salmon",
            "ing_mackerel",
            "ing_mackerel_meal",
            "ing_menhaden",
            "ing_menhaden_fish_meal",
            "ing_menhaden_oil",
            "ing_ocean_fish",
            "ing_ocean_fish_meal",
            "ing_pollock",
            "ing_salmon",
            "ing_salmon_fresh",
            "ing_salmon_meal",
            "ing_salmon_oil",
            "ing_sardine",
            "ing_sardine_meal",
            "ing_sardine_oil",
            "ing_sardines",
            "ing_tilapia",
            "ing_trout",
            "ing_trout_meal",
            "ing_tuna",
            "ing_tuna_fresh",
            "ing_whitefish",
            "ing_whitefish_fresh",
            "ing_whitefish_meal"
        ],
        "lamb": [
            "ing_lamb",
            "ing_lamb_fat",
            "ing_lamb_fresh",
            "ing_lamb_heart",
            "ing_lamb_liver",
            "ing_lamb_meal"
        ],
        // Its own family, not a corner of `fish`. Shellfish allergy is a distinct allergen
        // (tropomyosin, not the parvalbumin of finned fish), which is why these ids are kept
        // out of `fish` — but "Shellfish" is pickable from the ingredient search, and
        // without a family of its own it would whole-word-match only the literal word and
        // leave Shrimp, Crab, Lobster, Mussel, Squid and Krill unflagged. That is the same
        // silent gap the Dairy chip had.
        "shellfish": [
            "ing_clam",
            "ing_crab",
            "ing_crab_meal",
            "ing_green_lipped_mussel",
            "ing_krill",
            "ing_krill_meal",
            "ing_krill_oil",
            "ing_lobster",
            "ing_mussel",
            "ing_shellfish",
            "ing_shrimp",
            "ing_shrimp_meal",
            "ing_squid"
        ],
        "soy": [
            "ing_edamame",
            "ing_hydrolyzed_soy",
            "ing_soy_flour",
            "ing_soy",
            "ing_soy_hulls",
            "ing_soy_lecithin",
            "ing_soy_protein",
            "ing_soy_protein_concentrate",
            "ing_soy_protein_isolate",
            "ing_soybean_meal",
            "ing_soybean_oil",
            "ing_soybeans",
            "ing_tofu"
        ],
        "wheat": [
            "ing_spelt",
            "ing_wheat",
            "ing_wheat_bran",
            "ing_wheat_flour",
            "ing_wheat_germ",
            "ing_wheat_gluten",
            "ing_wheat_middlings",
            "ing_whole_wheat"
        ],
    ]

    /// True when `ingredient` belongs to `allergen`'s family, or its name contains the
    /// allergen as a whole word.
    ///
    /// The name check tokenises both sides rather than using `contains`, which is what let
    /// "wheat" match "Buckwheat".
    static func matches(allergen: String, ingredient: Ingredient) -> Bool {
        guard !allergen.isEmpty else { return false }

        // A curated family is **authoritative**: when the allergen has one, membership is
        // the whole answer and the name fallback is not consulted. Falling through re-admits
        // every ingredient the family deliberately leaves out — allergen "milk" matched
        // *Milk thistle* by whole word, and "butter" matched *Peanut butter* and *Shea
        // butter*, each forcing score 0 and "Avoid". The exclusions are medical calls; a
        // string test must not be able to overrule them.
        if let family = family(namedBy: allergen) {
            return family.contains(ingredient.id)
        }

        // Only for allergens with no family — a specific ingredient picked from the search.
        return containsWholeWord(allergen, in: ingredient.commonName)
    }

    /// Ingredient names that mean *the whole family* rather than one member of it.
    ///
    /// Custom allergens come from the full ingredient search and are stored as the
    /// ingredient's own name, so "milk" and "salmon" arrive in exactly the same shape — and
    /// only the first should widen. Someone who picked Salmon means salmon; expanding it to
    /// the fish family would force "Avoid" on Tuna, Cod, Whitefish and 39 others they never
    /// asked about. Someone who picked Milk means dairy, and whole-word matching cannot
    /// reach inside **Buttermilk** on its own.
    ///
    /// Keyed on the generic terms only, so the widening is enumerable rather than inferred.
    private static let genericNames: [String: String] = [
        "milk": "dairy",
        "butter": "dairy",
        "fish": "fish",
        "poultry": "chicken",
        "soy": "soy",
    ]

    /// The family an allergen widens to, if it is a generic term. `nil` for a specific
    /// ingredient, which then matches only itself.
    static func family(namedBy allergen: String) -> Set<String>? {
        if let ids = ingredientIds[allergen] { return ids }
        guard let key = genericNames[allergen] else { return nil }
        return ingredientIds[key]
    }

    /// Whole-word containment with light plural folding.
    ///
    /// Word-level rather than `contains`, which is what let "wheat" match "Buckwheat". The
    /// plural fold is what keeps the *narrowing* honest: the old substring test happened to
    /// catch "potato" in "Potatoes" and "sardine" in "Sardines", and dropping that would
    /// have quietly un-protected every custom allergen picked from the ingredient search
    /// whose stored singular differs from the label's plural.
    static func containsWholeWord(_ needle: String, in haystack: String) -> Bool {
        let needleWords = words(needle)
        let hayWords = words(haystack)
        guard !needleWords.isEmpty, hayWords.count >= needleWords.count else { return false }

        for start in 0...(hayWords.count - needleWords.count) {
            let window = hayWords[start..<(start + needleWords.count)]
            if zip(needleWords, window).allSatisfy(sameWord) { return true }
        }
        return false
    }

    private static func words(_ s: String) -> [String] {
        s.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    private static func sameWord(_ a: String, _ b: String) -> Bool {
        a == b || !singularForms(a).isDisjoint(with: singularForms(b))
    }

    /// Every plausible singular of a word, not one chosen singular.
    ///
    /// Picking one is ambiguous and gets it wrong: "sardines" could drop "s" to "sardine"
    /// or "es" to "sardin", and a stemmer that committed to the "es" rule stopped matching
    /// the ingredient literally named "Sardine". Collecting the candidates and intersecting
    /// costs nothing at this size and cannot pick the wrong branch.
    ///
    /// Crude on purpose — it only has to reconcile an ingredient name with itself, not be a
    /// general stemmer.
    private static func singularForms(_ word: String) -> Set<String> {
        var forms: Set<String> = [word]
        if word.hasSuffix("ies"), word.count > 4 { forms.insert(String(word.dropLast(3)) + "y") }
        if word.hasSuffix("es"), word.count > 3 { forms.insert(String(word.dropLast(2))) }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 3 { forms.insert(String(word.dropLast())) }
        return forms
    }
}

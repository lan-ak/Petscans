import Foundation
import SwiftData

/// Seeds data for App Store screenshots.
///
/// Every product below is a real row from the bundled `catalog.sqlite` — real
/// GTIN, real brand, real retail name, real pack shot, real ingredient list.
/// The previous version invented products ("Generic Brand", `imageUrl: nil`),
/// which is why the live screenshots had blank product headers and redacted
/// title bars. A store listing for a scanner that can't show it recognizing
/// anything is arguing against itself.
///
/// Pet is "Luna", allergic to chicken and wheat, so the same three products
/// produce a clean pass, a caution, and an allergen conflict — the three
/// verdicts the app exists to deliver.
///
/// Scores and explanations here are authored, not computed, so they have to be
/// kept honest against the real ingredient lists above them. If you swap a
/// product, swap its ingredients and its reasoning too.
enum ScreenshotDataSeeder {

    static func seed(context: ModelContext) {
        let pet = Pet(
            name: "Luna",
            species: .dog,
            allergens: ["chicken", "wheat"]
        )
        context.insert(pet)

        let scans = [
            createExcellentScan(),
            createGoodScan(),
            createAvoidScan()
        ]

        for scan in scans {
            context.insert(scan)
        }

        try? context.save()
    }

    // MARK: - Excellent — Merrick, grain-free beef

    /// The hero shot. Nothing in it conflicts with Luna's chicken/wheat profile,
    /// so it demonstrates a clean pass on a brand people recognize off a shelf.
    private static func createExcellentScan() -> Scan {
        let matchedIngredients = [
            MatchedIngredient(ingredientId: "ing_beef_fresh", labelName: "Deboned Beef", rank: 1),
            MatchedIngredient(ingredientId: "ing_lamb_meal", labelName: "Lamb Meal", rank: 2),
            MatchedIngredient(ingredientId: "ing_sweet_potato", labelName: "Sweet Potatoes", rank: 3),
            MatchedIngredient(ingredientId: "ing_peas", labelName: "Peas", rank: 4),
            MatchedIngredient(ingredientId: "ing_flaxseed", labelName: "Flaxseed Oil", rank: 5),
            MatchedIngredient(ingredientId: "ing_apples", labelName: "Apples", rank: 6),
            MatchedIngredient(ingredientId: "ing_salmon_oil", labelName: "Salmon Oil", rank: 7),
            MatchedIngredient(ingredientId: "ing_blueberries", labelName: "Blueberries", rank: 8)
        ]

        let scoreBreakdown = ScoreBreakdown(
            total: 92,
            safety: 95,
            suitability: 88,
            processing: 90,
            flags: [],
            unmatched: [],
            matchedCount: 8,
            totalCount: 8,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Named whole-meat first ingredient", impact: .positive, ingredientName: "Deboned Beef"),
                    ExplanationFactor(id: "2", description: "Rich in omega-3 fatty acids", impact: .positive, ingredientName: "Salmon Oil"),
                    ExplanationFactor(id: "3", description: "Antioxidant-rich whole fruit", impact: .positive, ingredientName: "Blueberries")
                ],
                summary: "All ingredients are safe and beneficial for dogs."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "No allergens detected", impact: .positive, ingredientName: nil)
                ],
                summary: "No allergen conflicts found for Luna."
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Majority minimally processed", impact: .positive, ingredientName: nil)
                ],
                summary: "Mostly minimally processed ingredients."
            )
        )

        return Scan(
            barcode: "00022808383390",
            productName: "Grain-Free Real Texas Beef + Sweet Potato Recipe",
            brand: "Merrick",
            imageUrl: "https://i5.walmartimages.com/seo/Merrick-Grain-Free-Real-Texas-Beef-Sweet-Potato-Recipe-Dry-Dog-Food-4-lb_6d8f5d88-c690-4c06-bcf8-53de4189cad3_1.0660777aea1c77aabf1dddfabadab473.jpeg",
            category: .food,
            targetSpecies: .dog,
            rawIngredientText: "Deboned Beef, Lamb Meal, Sweet Potatoes, Peas, Potatoes, Flaxseed Oil, Apples, Salmon Oil, Blueberries",
            matchedIngredients: matchedIngredients,
            scoreBreakdown: scoreBreakdown
        )
    }

    // MARK: - Good — Purina ONE, salmon

    /// A middling result: safe for Luna, but carrying a filler and one vague
    /// ingredient. Shows the app doing something more useful than pass/fail.
    private static func createGoodScan() -> Scan {
        let matchedIngredients = [
            MatchedIngredient(ingredientId: "ing_hydrolyzed_salmon", labelName: "Salmon", rank: 1),
            MatchedIngredient(ingredientId: "ing_rice_flour", labelName: "Rice Flour", rank: 2),
            MatchedIngredient(ingredientId: "ing_barley", labelName: "Pearled Barley", rank: 3),
            MatchedIngredient(ingredientId: "ing_oatmeal", labelName: "Oat Meal", rank: 4),
            MatchedIngredient(ingredientId: "ing_corn_gluten_meal", labelName: "Corn Gluten Meal", rank: 5),
            MatchedIngredient(ingredientId: "ing_beef_fat", labelName: "Beef Fat", rank: 6),
            MatchedIngredient(ingredientId: nil, labelName: "Liver Flavor", rank: 7)
        ]

        let scoreBreakdown = ScoreBreakdown(
            total: 68,
            safety: 75,
            suitability: 82,
            processing: 58,
            flags: [
                WarningFlag(
                    severity: .info,
                    title: "Unspecified ingredient",
                    explain: "\"Liver flavor\" doesn't name a species or a source, so there's no way to tell what's actually in it.",
                    ingredientId: nil,
                    source: nil,
                    type: .general
                ),
                WarningFlag(
                    severity: .warn,
                    title: "Plant protein filler",
                    explain: "Corn gluten meal raises the protein number on the label without contributing the amino acid profile a dog gets from meat.",
                    ingredientId: "ing_corn_gluten_meal",
                    source: "AAFCO 2024",
                    type: .safety
                )
            ],
            unmatched: ["Liver Flavor"],
            matchedCount: 6,
            totalCount: 7,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Named whole-fish first ingredient", impact: .positive, ingredientName: "Salmon"),
                    ExplanationFactor(id: "2", description: "Whole grain carbohydrate", impact: .positive, ingredientName: "Pearled Barley"),
                    ExplanationFactor(id: "3", description: "Plant protein used as filler", impact: .negative, ingredientName: "Corn Gluten Meal")
                ],
                summary: "Generally safe with minor considerations."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "No allergens detected", impact: .positive, ingredientName: nil)
                ],
                summary: "No allergen conflicts found for Luna."
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Refined grain fraction", impact: .negative, ingredientName: "Rice Flour"),
                    ExplanationFactor(id: "2", description: "Highly processed protein isolate", impact: .negative, ingredientName: "Corn Gluten Meal")
                ],
                summary: "Several refined and processed ingredients."
            )
        )

        return Scan(
            barcode: "00370255731777",
            productName: "Sensitive Skin & Stomach Dry Dog Food",
            brand: "Purina ONE",
            imageUrl: "https://i5.walmartimages.com/seo/Purina-One-31-lb-Sensitive-Skin-and-Stomach-Dog-Food_d6af95aa-cd09-4619-8147-437e9c8bf4e0.27a051e993fe9e5a36a247590b3b8a34.jpeg",
            category: .food,
            targetSpecies: .dog,
            rawIngredientText: "Salmon, Rice Flour, Pearled Barley, Oat Meal, Corn Gluten Meal, Beef Fat, Liver Flavor",
            matchedIngredients: matchedIngredients,
            scoreBreakdown: scoreBreakdown
        )
    }

    // MARK: - Avoid — Milk-Bone, wheat + additives

    /// The allergen shot. Wheat flour is the first ingredient and poultry digest
    /// is chicken-derived, so this trips both of Luna's allergens at once and
    /// carries preservatives and dye on top of it.
    private static func createAvoidScan() -> Scan {
        let matchedIngredients = [
            MatchedIngredient(ingredientId: "ing_wheat", labelName: "Wheat Flour", rank: 1),
            MatchedIngredient(ingredientId: "ing_meat_and_bone_meal", labelName: "Meat and Bone Meal", rank: 2),
            MatchedIngredient(ingredientId: "ing_sorbitol", labelName: "Sugar", rank: 3),
            MatchedIngredient(ingredientId: "ing_poultry_digest", labelName: "Poultry Digest", rank: 4),
            MatchedIngredient(ingredientId: "ing_bha", labelName: "BHA/BHT", rank: 5),
            MatchedIngredient(ingredientId: "ing_artificial_colors", labelName: "Added Color", rank: 6)
        ]

        let scoreBreakdown = ScoreBreakdown(
            total: 0,
            safety: 38,
            suitability: 0,
            processing: 22,
            flags: [
                WarningFlag(
                    severity: .high,
                    title: "Allergen detected: Wheat",
                    explain: "Wheat flour is the first ingredient, and wheat is listed in Luna's allergen profile.",
                    ingredientId: "ing_wheat",
                    source: nil,
                    type: .allergen
                ),
                WarningFlag(
                    severity: .high,
                    title: "Allergen detected: Chicken",
                    explain: "Poultry digest is chicken-derived, and chicken is listed in Luna's allergen profile.",
                    ingredientId: "ing_poultry_digest",
                    source: nil,
                    type: .allergen
                ),
                WarningFlag(
                    severity: .warn,
                    title: "Controversial preservative",
                    explain: "BHA and BHT are synthetic preservatives. Both are permitted in pet food, but are restricted in human food in several countries.",
                    ingredientId: "ing_bha",
                    source: "FDA 21 CFR 582.3169",
                    type: .safety
                ),
                WarningFlag(
                    severity: .warn,
                    title: "Artificial coloring",
                    explain: "Added color does nothing for the dog. It's there so the treat looks like meat to the person buying it.",
                    ingredientId: "ing_artificial_colors",
                    source: nil,
                    type: .safety
                ),
                WarningFlag(
                    severity: .warn,
                    title: "Unnamed meat source",
                    explain: "\"Meat and bone meal\" doesn't identify a species, so the protein quality can't be assessed.",
                    ingredientId: "ing_meat_and_bone_meal",
                    source: "AAFCO 2024",
                    type: .safety
                )
            ],
            unmatched: [],
            matchedCount: 6,
            totalCount: 6,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Synthetic preservative", impact: .negative, ingredientName: "BHA/BHT"),
                    ExplanationFactor(id: "2", description: "Unnamed protein source", impact: .negative, ingredientName: "Meat and Bone Meal"),
                    ExplanationFactor(id: "3", description: "Added sugar in a daily treat", impact: .negative, ingredientName: "Sugar")
                ],
                summary: "Contains ingredients that may require attention."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Contains allergen for Luna", impact: .negative, ingredientName: "Wheat Flour"),
                    ExplanationFactor(id: "2", description: "Contains allergen for Luna", impact: .negative, ingredientName: "Poultry Digest")
                ],
                summary: "Contains 2 ingredients Luna should avoid. Score set to Avoid.",
                labelOverride: .avoid
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Refined flour base", impact: .negative, ingredientName: "Wheat Flour"),
                    ExplanationFactor(id: "2", description: "Rendered by-product", impact: .negative, ingredientName: "Meat and Bone Meal")
                ],
                summary: "Several processed or ultra-processed ingredients."
            )
        )

        return Scan(
            barcode: "00079100902071",
            productName: "MaroSnacks Small Dog Treats With Bone Marrow",
            brand: "Milk-Bone",
            imageUrl: "https://i5.walmartimages.com/seo/Milk-Bone-MaroSnacks-Small-Dog-Treats-With-Bone-Marrow-10-Ounces_64feec16-9d1e-4ed2-be4e-8b40c9ae14c9.8e796c560ff714305e7734c8be383cf2.jpeg",
            category: .treat,
            targetSpecies: .dog,
            rawIngredientText: "Wheat Flour, Meat and Bone Meal, Sugar, Poultry Digest, Beef Fat (Preserved with BHA/BHT), Salt, Added Color",
            matchedIngredients: matchedIngredients,
            scoreBreakdown: scoreBreakdown
        )
    }
}

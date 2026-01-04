import Foundation
import SwiftData

/// Seeds realistic mock data for App Store screenshots
enum ScreenshotDataSeeder {

    static func seed(context: ModelContext) {
        // Create a pet
        let pet = Pet(
            name: "Max",
            species: .dog,
            allergens: ["chicken", "wheat"]
        )
        context.insert(pet)

        // Create sample scans with different score levels
        let scans = [
            createExcellentScan(),
            createGoodScan(),
            createCautionScan()
        ]

        for scan in scans {
            context.insert(scan)
        }

        try? context.save()
    }

    // MARK: - Sample Scans

    private static func createExcellentScan() -> Scan {
        let matchedIngredients = [
            MatchedIngredient(ingredientId: "ing_salmon", labelName: "Salmon", rank: 1),
            MatchedIngredient(ingredientId: "ing_sweet_potato", labelName: "Sweet Potato", rank: 2),
            MatchedIngredient(ingredientId: "ing_peas", labelName: "Peas", rank: 3),
            MatchedIngredient(ingredientId: "ing_flaxseed", labelName: "Flaxseed", rank: 4),
            MatchedIngredient(ingredientId: "ing_blueberries", labelName: "Blueberries", rank: 5),
            MatchedIngredient(ingredientId: "ing_spinach", labelName: "Spinach", rank: 6)
        ]

        let scoreBreakdown = ScoreBreakdown(
            total: 92,
            safety: 95,
            suitability: 88,
            processing: 90,
            flags: [],
            unmatched: [],
            matchedCount: 6,
            totalCount: 6,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "High-quality protein source", impact: .positive, ingredientName: "Salmon"),
                    ExplanationFactor(id: "2", description: "Rich in omega-3 fatty acids", impact: .positive, ingredientName: "Flaxseed"),
                    ExplanationFactor(id: "3", description: "Antioxidant-rich superfood", impact: .positive, ingredientName: "Blueberries")
                ],
                summary: "All ingredients are safe and beneficial for dogs."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "No allergens detected", impact: .positive, ingredientName: nil)
                ],
                summary: "No allergen conflicts found for Max."
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Majority minimally processed", impact: .positive, ingredientName: nil)
                ],
                summary: "Mostly minimally processed ingredients."
            )
        )

        return Scan(
            barcode: "850003592019",
            productName: "Wild Caught Salmon Recipe",
            brand: "Acana",
            imageUrl: nil,
            category: .food,
            targetSpecies: .dog,
            rawIngredientText: "Salmon, Sweet Potato, Peas, Flaxseed, Blueberries, Spinach",
            matchedIngredients: matchedIngredients,
            scoreBreakdown: scoreBreakdown
        )
    }

    private static func createGoodScan() -> Scan {
        let matchedIngredients = [
            MatchedIngredient(ingredientId: "ing_beef", labelName: "Beef", rank: 1),
            MatchedIngredient(ingredientId: "ing_brown_rice", labelName: "Brown Rice", rank: 2),
            MatchedIngredient(ingredientId: "ing_oatmeal", labelName: "Oatmeal", rank: 3),
            MatchedIngredient(ingredientId: "ing_carrots", labelName: "Carrots", rank: 4),
            MatchedIngredient(ingredientId: nil, labelName: "Natural Flavors", rank: 5)
        ]

        let scoreBreakdown = ScoreBreakdown(
            total: 68,
            safety: 75,
            suitability: 60,
            processing: 65,
            flags: [
                WarningFlag(
                    severity: .info,
                    title: "Unspecified ingredient",
                    explain: "Natural flavors is a broad term that may include various ingredients.",
                    ingredientId: nil,
                    source: nil,
                    type: .general
                )
            ],
            unmatched: ["Natural Flavors"],
            matchedCount: 4,
            totalCount: 5,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Quality protein source", impact: .positive, ingredientName: "Beef"),
                    ExplanationFactor(id: "2", description: "Whole grain carbohydrate", impact: .positive, ingredientName: "Brown Rice")
                ],
                summary: "Generally safe with minor considerations."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "No allergens detected", impact: .positive, ingredientName: nil)
                ],
                summary: "No allergen conflicts found for Max."
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Some processed ingredients", impact: .negative, ingredientName: nil)
                ],
                summary: "Some processed ingredients detected."
            )
        )

        return Scan(
            barcode: "017800149297",
            productName: "Adult Beef & Brown Rice",
            brand: "Purina ONE",
            imageUrl: nil,
            category: .food,
            targetSpecies: .dog,
            rawIngredientText: "Beef, Brown Rice, Oatmeal, Carrots, Natural Flavors",
            matchedIngredients: matchedIngredients,
            scoreBreakdown: scoreBreakdown
        )
    }

    private static func createCautionScan() -> Scan {
        let matchedIngredients = [
            MatchedIngredient(ingredientId: "ing_chicken", labelName: "Chicken", rank: 1),
            MatchedIngredient(ingredientId: "ing_wheat", labelName: "Wheat", rank: 2),
            MatchedIngredient(ingredientId: "ing_corn", labelName: "Corn", rank: 3),
            MatchedIngredient(ingredientId: "ing_chicken_byproduct", labelName: "Chicken By-Product Meal", rank: 4),
            MatchedIngredient(ingredientId: "ing_soy", labelName: "Soybean Meal", rank: 5)
        ]

        let scoreBreakdown = ScoreBreakdown(
            total: 0,
            safety: 50,
            suitability: 0,
            processing: 40,
            flags: [
                WarningFlag(
                    severity: .high,
                    title: "Allergen detected: Chicken",
                    explain: "This product contains chicken, which is listed in Max's allergen profile.",
                    ingredientId: "ing_chicken",
                    source: nil,
                    type: .allergen
                ),
                WarningFlag(
                    severity: .high,
                    title: "Allergen detected: Wheat",
                    explain: "This product contains wheat, which is listed in Max's allergen profile.",
                    ingredientId: "ing_wheat",
                    source: nil,
                    type: .allergen
                ),
                WarningFlag(
                    severity: .warn,
                    title: "By-product ingredient",
                    explain: "By-product meals are lower quality protein sources.",
                    ingredientId: "ing_chicken_byproduct",
                    source: nil,
                    type: .safety
                )
            ],
            unmatched: [],
            matchedCount: 5,
            totalCount: 5,
            scoreSource: .databaseVerified,
            ocrConfidence: nil,
            safetyExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Lower quality protein source", impact: .negative, ingredientName: "Chicken By-Product Meal"),
                    ExplanationFactor(id: "2", description: "Common filler ingredient", impact: .negative, ingredientName: "Corn")
                ],
                summary: "Contains ingredients that may require attention."
            ),
            suitabilityExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Contains allergen for Max", impact: .negative, ingredientName: "Chicken"),
                    ExplanationFactor(id: "2", description: "Contains allergen for Max", impact: .negative, ingredientName: "Wheat")
                ],
                summary: "Contains 2 ingredients Max should avoid. Score set to Avoid."
            ),
            processingExplanation: ScoreExplanation(
                factors: [
                    ExplanationFactor(id: "1", description: "Processed ingredient", impact: .negative, ingredientName: "Chicken By-Product Meal"),
                    ExplanationFactor(id: "2", description: "Processed ingredient", impact: .negative, ingredientName: "Soybean Meal")
                ],
                summary: "Several processed or ultra-processed ingredients."
            )
        )

        return Scan(
            barcode: "023100101460",
            productName: "Adult Complete Nutrition",
            brand: "Generic Brand",
            imageUrl: nil,
            category: .food,
            targetSpecies: .dog,
            rawIngredientText: "Chicken, Wheat, Corn, Chicken By-Product Meal, Soybean Meal",
            matchedIngredients: matchedIngredients,
            scoreBreakdown: scoreBreakdown
        )
    }
}

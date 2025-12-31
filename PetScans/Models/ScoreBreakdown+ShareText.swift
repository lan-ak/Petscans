import Foundation

extension ScoreBreakdown {
    /// Generate shareable text summary for this score breakdown
    func generateShareText(
        productName: String?,
        brand: String?,
        species: Species,
        category: Category
    ) -> String {
        var text = "PetScans Analysis\n"
        text += "━━━━━━━━━━━━━━━━━━\n\n"

        if let name = productName {
            text += "Product: \(name)\n"
        }
        if let brandName = brand {
            text += "Brand: \(brandName)\n"
        }

        text += "For: \(species.displayName)\n"
        text += "Type: \(category.displayName)\n\n"

        text += "Overall Score: \(Int(total))/100\n"
        text += "Safety: \(Int(safety))/100\n"

        if let nutritionScore = nutrition {
            text += "Nutrition: \(Int(nutritionScore))/100\n"
        }

        text += "Suitability: \(Int(suitability))/100\n"

        if !flags.isEmpty {
            text += "\nWarnings:\n"
            for flag in flags {
                text += "• \(flag.title): \(flag.explain)\n"
            }
        }

        text += "\n— Scanned with PetScans"

        return text
    }
}

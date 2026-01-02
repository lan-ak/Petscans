import Foundation

extension Pet {
    /// Formatted allergen count with proper pluralization (e.g., "1 allergen", "3 allergens")
    var allergenCountText: String {
        "\(allergens.count) allergen\(allergens.count == 1 ? "" : "s")"
    }
}

import Foundation

extension Pet {
    /// Formatted count of ingredients to avoid with proper pluralization
    var allergenCountText: String {
        "\(allergens.count) ingredient\(allergens.count == 1 ? "" : "s") to avoid"
    }
}

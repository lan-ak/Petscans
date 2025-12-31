import Foundation

enum Category: String, Codable, CaseIterable, Identifiable {
    case food
    case treat
    case cosmetic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "Food"
        case .treat: return "Treat"
        case .cosmetic: return "Cosmetic"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .treat: return "birthday.cake"
        case .cosmetic: return "sparkles"
        }
    }
}

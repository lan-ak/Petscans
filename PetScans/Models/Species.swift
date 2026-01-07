import Foundation

enum Species: String, Codable, CaseIterable, Identifiable {
    case dog
    case cat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dog: return "Dog"
        case .cat: return "Cat"
        }
    }

    var icon: String {
        switch self {
        case .dog: return "pawprint.fill"
        case .cat: return "pawprint.fill"
        }
    }
}

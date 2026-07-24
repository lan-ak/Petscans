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

    /// Distinct per species. Both cases used to return `pawprint`, which made
    /// the species picker carry no visual signal — an owner could tap past the
    /// segmented control (default `.dog`) and get dog scoring for a cat with
    /// nothing on screen indicating it.
    var icon: String {
        switch self {
        case .dog: return "dog.fill"
        case .cat: return "cat.fill"
        }
    }
}

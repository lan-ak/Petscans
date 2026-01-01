import Foundation
import SwiftData

@Model
final class Pet {
    var id: UUID
    var name: String
    var species: String
    var allergensJSON: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        species: Species,
        allergens: [String] = []
    ) {
        self.id = id
        self.name = name
        self.species = species.rawValue
        self.allergensJSON = (try? JSONEncoder().encode(allergens))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var speciesEnum: Species {
        Species(rawValue: species) ?? .dog
    }

    var allergens: [String] {
        get {
            guard let data = allergensJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            allergensJSON = (try? JSONEncoder().encode(newValue))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            updatedAt = Date()
        }
    }
}

extension Pet: Identifiable {}

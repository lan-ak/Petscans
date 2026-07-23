import Foundation
import SwiftData
import SuperwallKit

/// Owns every pet-derived Superwall user attribute so paywall copy can address
/// the animal by name. `pet_name` is never empty — it falls back to "your pet"
/// so `{{ user.pet_name }}` renders readable copy without needing a Liquid
/// filter in the paywall editor.
@MainActor
enum SuperwallUserAttributes {
    static let noPetFallback = "your pet"

    /// Roster primary from the last sync, so a scan run without a pet selected
    /// can restore `pet_name` without another fetch.
    private static var primaryName = noPetFallback
    private static var primarySpecies = Species.dog.rawValue

    /// Fetches the pet roster and pushes name/count/species to Superwall.
    /// - Parameter fallbackSpecies: species from the onboarding picker, used
    ///   only when the user finished onboarding without creating a pet.
    static func syncPets(modelContext: ModelContext, fallbackSpecies: Species? = nil) {
        let pets = (try? modelContext.fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\Pet.createdAt)])
        )) ?? []

        primaryName = pets.first?.name ?? noPetFallback
        primarySpecies = pets.first?.speciesEnum.rawValue
            ?? fallbackSpecies?.rawValue ?? Species.dog.rawValue

        Superwall.shared.setUserAttributes([
            "pet_name": primaryName,
            "pet_names": pets.map(\.name).joined(separator: ", "),
            "pet_count": pets.count,
            "pet_species": primarySpecies
        ])
    }

    /// Points `pet_name` at the pet a scan was run for; `nil` restores the
    /// roster primary from the last `syncPets` call.
    static func setFocusedPet(_ pet: Pet?) {
        Superwall.shared.setUserAttributes([
            "pet_name": pet?.name ?? primaryName,
            "pet_species": pet?.speciesEnum.rawValue ?? primarySpecies
        ])
    }
}

import Foundation
import SwiftData

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

        // The cached primaries above are set either way, so a later call once
        // Superwall is up still has the right roster to fall back on.
        SuperwallSafe.setUserAttributes([
            "pet_name": primaryName,
            "pet_names": pets.map(\.name).joined(separator: ", "),
            "pet_count": pets.count,
            "pet_species": primarySpecies
        ])
    }

    /// Pushes the avoidance groups picked during onboarding.
    ///
    /// Sent three ways because each answers a different question in the
    /// dashboard: `avoid_groups` for copy, `avoid_group_count` for "did they
    /// engage with the question at all", and a boolean per group because
    /// targeting rules are far easier to write against booleans than against a
    /// joined string. Every group's boolean is always set — an absent attribute
    /// and a false one behave differently in targeting, and only the explicit
    /// false is truthful about a user who saw the question and said no.
    static func setAvoidanceGroups(_ groups: Set<AvoidanceGroup>) {
        // Enum case order, not Set order, so the string is stable between users
        // and launches.
        let ordered = AvoidanceGroup.allCases.filter(groups.contains)

        var attributes: [String: Any] = [
            // Empty string rather than nil so `{{ user.avoid_groups }}` renders
            // without a Liquid filter, same reasoning as `pet_name` above.
            "avoid_groups": ordered.map(\.rawValue).joined(separator: ","),
            "avoid_group_count": ordered.count
        ]

        for group in AvoidanceGroup.allCases {
            attributes[group.attributeKey] = groups.contains(group)
        }

        SuperwallSafe.setUserAttributes(attributes)
    }

    /// Pushes the food the user searched during the onboarding AHA moment, so a
    /// paywall can reference the exact product and its verdict ("We found 3 things
    /// in {{ searched_food_name }} you'll want to avoid"). Set when the result is
    /// shown; absence means the user skipped the search.
    static func setSearchedFood(_ result: OnboardingFoodResult) {
        SuperwallSafe.setUserAttributes([
            "searched_food": true,
            "searched_food_name": result.name,
            "searched_food_brand": result.brand ?? "",
            "searched_food_score": Int(result.score.rounded()),
            "searched_food_verdict": result.verdict.rawValue,
            "searched_food_flag_count": result.flagCount
        ])
    }

    /// Points `pet_name` at the pet a scan was run for; `nil` restores the
    /// roster primary from the last `syncPets` call.
    static func setFocusedPet(_ pet: Pet?) {
        SuperwallSafe.setUserAttributes([
            "pet_name": pet?.name ?? primaryName,
            "pet_species": pet?.speciesEnum.rawValue ?? primarySpecies
        ])
    }
}

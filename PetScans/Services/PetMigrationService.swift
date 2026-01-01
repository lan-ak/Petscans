import Foundation
import SwiftData

struct PetMigrationService {
    private static let migrationKey = "hasMigratedAllergensToProfiles_v1"

    static func migrateIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let petAllergensData = UserDefaults.standard.data(forKey: "petAllergens") ?? Data()
        let existingAllergens = (try? JSONDecoder().decode([String].self, from: petAllergensData)) ?? []

        if !existingAllergens.isEmpty {
            let defaultPet = Pet(
                name: "My Pet",
                species: .dog,
                allergens: existingAllergens
            )
            modelContext.insert(defaultPet)
            try? modelContext.save()
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}

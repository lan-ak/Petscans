import SwiftUI
import SwiftData

@main
struct PetScansApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Scan.self, Pet.self])
        let config = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }

        let context = ModelContext(container)
        PetMigrationService.migrateIfNeeded(modelContext: context)

        Task {
            await ProductCacheManager.shared.initialize()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(ColorTokens.brandPrimary)
                .background(ColorTokens.backgroundPrimary)
        }
        .modelContainer(container)
    }
}

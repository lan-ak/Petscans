import SwiftUI
import SwiftData
import SuperwallKit

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

        // Configure Superwall (non-blocking)
        Task {
            Superwall.configure(apiKey: "pk_Dk2TvC85dqlZYwhyajUTT")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(ColorTokens.brandPrimary)
                .background(ColorTokens.backgroundPrimary)
                .onOpenURL { url in
                    Superwall.handleDeepLink(url)
                }
        }
        .modelContainer(container)
    }
}

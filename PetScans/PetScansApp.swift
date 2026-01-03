import SwiftUI
import SwiftData
import SuperwallKit

@main
struct PetScansApp: App {
    let container: ModelContainer

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    init() {
        let schema = Schema([Scan.self, Pet.self])
        let config: ModelConfiguration

        // Use in-memory store for UI tests to have clean, predictable state
        if Self.isUITesting {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            config = ModelConfiguration(schema: schema)
        }

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }

        let context = ModelContext(container)

        if Self.isUITesting {
            // Seed screenshot data if requested
            if ProcessInfo.processInfo.arguments.contains("-SeedScreenshotData") {
                ScreenshotDataSeeder.seed(context: context)
            }
        } else {
            PetMigrationService.migrateIfNeeded(modelContext: context)

            Task {
                await ProductCacheManager.shared.initialize()
            }

            // Configure Superwall (non-blocking)
            Task {
                Superwall.configure(apiKey: "pk_Dk2TvC85dqlZYwhyajUTT")
            }
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

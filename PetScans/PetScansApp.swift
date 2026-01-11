import SwiftUI
import SwiftData
import SuperwallKit

@main
struct PetScansApp: App {
    let container: ModelContainer
    @State private var isReady = false

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    init() {
        // ModelContainer creation blocks but is unavoidable for SwiftData
        // The iOS launch screen (from Info.plist) covers this delay
        let schema = Schema([Scan.self, Pet.self])
        let config: ModelConfiguration

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

        // Seed test data if UI testing
        if Self.isUITesting {
            let context = ModelContext(container)
            if ProcessInfo.processInfo.arguments.contains("-SeedScreenshotData") {
                ScreenshotDataSeeder.seed(context: context)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isReady || Self.isUITesting {
                    // ContentView only created when ready (avoids triggering IngredientDatabase on launch)
                    ContentView()
                } else {
                    // SplashView is lightweight - renders immediately
                    SplashView()
                        .onAppear {
                            Task {
                                await deferredInit()
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isReady = true
                                }
                            }
                        }
                }
            }
            .tint(ColorTokens.brandPrimary)
            .background(ColorTokens.backgroundPrimary)
            .onOpenURL { url in
                Superwall.handleDeepLink(url)
            }
            .modelContainer(container)
        }
    }

    @MainActor
    private func deferredInit() async {
        // Pre-load custom fonts (forces font registration before views need them)
        _ = UIFont(name: "Quicksand-Bold", size: 1)
        _ = UIFont(name: "Quicksand-Medium", size: 1)
        _ = UIFont(name: "Quicksand-Regular", size: 1)

        // Pre-warm the ingredient database (starts loading in background on .shared access)
        // This ensures the database is fully loaded before ContentView appears
        await IngredientDatabase.shared.waitForLoad()

        // Run pet migration
        let context = ModelContext(container)
        PetMigrationService.migrateIfNeeded(modelContext: context)

        // Configure Superwall
        Superwall.configure(apiKey: APIKeys.superwall)

        // Initialize product cache
        await ProductCacheManager.shared.initialize()
    }
}

import SwiftUI
import SwiftData
import SuperwallKit
import UIKit

/// Meta's SDK has to initialize inside `didFinishLaunchingWithOptions` to attribute
/// an install to the ad click that caused it, and SwiftUI's `App.init` runs too early
/// to see `launchOptions`. This adaptor is the only reason the app has a delegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AttributionService.start(launchOptions: launchOptions)

        // Superwall's docs are explicit that configure belongs "as soon as your
        // app launches". It used to sit in `deferredInit()`, behind an `await`
        // on the ingredient database — which meant the SDK only started fetching
        // campaign settings and preloading paywalls after that finished. A first
        // run reaches `onboarding_complete` within seconds of launch, so that
        // delay ate most of the preload window for the one paywall that matters
        // most. Configuring here also removes the window in which UI could touch
        // `Superwall.shared` before it exists.
        //
        // Skipped under `-UITesting` so screenshot runs make no network calls and
        // StoreKit never prompts; `SuperwallSafe` handles the resulting no-op.
        if !PetScansApp.isUITesting {
            Superwall.configure(apiKey: APIKeys.superwall)
            // Forwards purchase/trial events to Meta for ad attribution.
            // Superwall holds the delegate weakly, hence the static instance.
            Superwall.shared.delegate = SuperwallAttributionDelegate.shared
        }

        return true
    }
}

@main
struct PetScansApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
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
                // Meta only claims its own fb<app-id> callbacks; everything else
                // falls through to Superwall.
                guard !AttributionService.handleDeepLink(url) else { return }
                Superwall.handleDeepLink(url)
            }
            .modelContainer(container)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // The app delegate's applicationDidBecomeActive never fires in a
            // scene-based app, so activation has to be observed here.
            if newPhase == .active {
                AttributionService.logAppActivation()
            }
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

        // Superwall itself is configured in the app delegate, at launch. Only the
        // pet attributes wait for here, since they need the model container and
        // the migration above to have run.
        SuperwallUserAttributes.syncPets(modelContext: context)
    }
}

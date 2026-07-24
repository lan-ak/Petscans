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
        LaunchMetrics.mark("attributionStarted")

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
        LaunchMetrics.mark("superwallConfigured")

        // Touching `.shared` is what starts the database's background decode. Doing
        // it here rather than from a view means the JSON parse overlaps the SDK
        // setup above and the first frame, instead of queueing up behind them.
        _ = IngredientDatabase.shared

        LaunchMetrics.mark("didFinishLaunching")
        return true
    }
}

@main
struct PetScansApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    init() {
        LaunchMetrics.mark("appInitStart")

        // ModelContainer creation blocks but is unavoidable for SwiftData, and it
        // runs here in `App.init` — before the app delegate and before the first
        // frame — so the launch screen is all the user sees until it returns.
        let schema = Schema([Scan.self, Pet.self])
        let config: ModelConfiguration

        if Self.isUITesting {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            config = ModelConfiguration(schema: schema, url: Self.storeURL())
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

        LaunchMetrics.mark("appInitEnd")
    }

    /// The same path SwiftData picks by default — `Application Support/default.store`
    /// — but reached by way of a `create: true` directory lookup.
    ///
    /// That difference is worth seconds on a first launch. `Application Support` does
    /// not exist in a fresh container, so letting SwiftData resolve the default URL
    /// means `addPersistentStore` fails with `NSCocoaErrorDomain 512`, after which
    /// CoreData stats every ancestor directory up to `/` and dumps a few hundred
    /// diagnostic log lines before recovering by creating the folder itself. Creating
    /// it up front skips the whole failure-and-recovery path.
    ///
    /// The filename has to stay `default.store`: it is where existing installs
    /// already keep their scans and pets, so matching it exactly is what makes this
    /// a no-migration change.
    private static func storeURL() -> URL {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return appSupport.appending(path: "default.store")
        } catch {
            // Nothing works without a store, and this only fails if the container
            // itself is unwritable — the same class of unrecoverable state the
            // ModelContainer `fatalError` above already covers.
            fatalError("Could not create Application Support directory: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Rendered on the first frame, with no splash screen in front of it.
            //
            // There used to be one, gated on the ingredient database having finished
            // loading. Nothing the user can see at this point reads that database —
            // onboarding doesn't, and neither does the tab bar — so the wait only
            // delayed the UI. Everything that does need it (`IngredientMatcher`,
            // `ScoreCalculator`) awaits `waitForLoad()` on its own.
            // Marked here, not in ContentView: this closure runs when the scene
            // connects, which brackets how much of the gap to `firstFrame` is UIKit
            // bringing the scene up versus SwiftUI evaluating the view tree.
            let _ = LaunchMetrics.markOnce("sceneConnected")

            ContentView()
                .task { await deferredInit() }
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

    /// Runs after the first frame, off the launch critical path. Nothing in here
    /// gates the UI — that is the whole reason it is a `.task` and not part of
    /// `init`.
    @MainActor
    private func deferredInit() async {
        // One cold launch = one session. Gates the rating prompt on the user
        // having come back at least once, which a scan count alone can't tell.
        ReviewPrompt.recordSessionStart()

        // Pre-load custom fonts (forces font registration before views need them)
        _ = UIFont(name: "Quicksand-Bold", size: 1)
        _ = UIFont(name: "Quicksand-Medium", size: 1)
        _ = UIFont(name: "Quicksand-Regular", size: 1)

        // Run pet migration
        let context = ModelContext(container)
        PetMigrationService.migrateIfNeeded(modelContext: context)

        // Superwall itself is configured in the app delegate, at launch. Only the
        // pet attributes wait for here, since they need the model container and
        // the migration above to have run.
        SuperwallUserAttributes.syncPets(modelContext: context)
    }
}

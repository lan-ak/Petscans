import Foundation
import SwiftData
import SuperwallKit

/// Centralizes app initialization that can run after the UI is displayed
enum AppInitializer {
    /// Performs all deferred initialization tasks
    /// Call this after showing the splash screen
    @MainActor
    static func initialize(modelContext: ModelContext) async {
        // Run pet migration if needed
        PetMigrationService.migrateIfNeeded(modelContext: modelContext)

        // Initialize services concurrently
        async let cacheInit: () = ProductCacheManager.shared.initialize()
        async let superwallInit: () = configureSuperwall()

        _ = await (cacheInit, superwallInit)
    }

    private static func configureSuperwall() async {
        Superwall.configure(apiKey: "pk_Dk2TvC85dqlZYwhyajUTT")
    }
}

import SwiftUI
import SwiftData

@main
struct PetScansApp: App {
    init() {
        // Initialize the product cache manager on app launch
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
        .modelContainer(for: Scan.self)
    }
}

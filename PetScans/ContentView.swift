import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var shouldShowOnboarding: Bool {
        // Launch arguments override for UI testing
        if ProcessInfo.processInfo.arguments.contains("-ShowOnboarding") {
            return true
        }
        if ProcessInfo.processInfo.arguments.contains("-SkipOnboarding") {
            return false
        }
        return !hasCompletedOnboarding
    }

    var body: some View {
        if shouldShowOnboarding {
            OnboardingView {
                withStandardAnimation {
                    hasCompletedOnboarding = true
                }
            }
            .dismissKeyboardOnTap()
            .keyboardToolbar()
        } else {
            MainTabView()
                .keyboardToolbar()
                .task {
                    // Reached both by finishing onboarding and by launching as an
                    // existing user, so the prompt lands once the app has shown its
                    // value rather than on a cold splash screen — asking there costs
                    // a large share of opt-ins, and opt-in rate is what decides
                    // whether Meta attribution has an IDFA to work with at all.
                    // iOS shows the prompt only once per install; later calls return
                    // the cached status without any UI.
                    try? await Task.sleep(for: .milliseconds(500))
                    await AttributionService.requestTrackingAuthorization()
                }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ScannerView()
                .tabItem {
                    Label("Search", systemImage: "camera.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Scan.self, inMemory: true)
}

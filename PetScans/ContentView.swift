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
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ScannerView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
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

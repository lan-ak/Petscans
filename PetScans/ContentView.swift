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
            // No keyboardToolbar() here: onboarding has one text field, and a
            // Cancel/Done bar above the keyboard costs height on the page that
            // can least afford it. Dismissal is covered by the tap-to-dismiss
            // above and by the name field's return key.
            .dismissKeyboardOnTap()
        } else {
            // The ATT prompt is requested after the first completed scan, not
            // here — see ScannerViewModel. Asking on this screen raced the
            // camera permission alert that ScannerView triggers on appear, and
            // iOS drops the ATT prompt when another system alert is up, leaving
            // the status .notDetermined permanently with no second chance.
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

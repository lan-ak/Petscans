import SwiftUI
import StoreKit

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
        content
            // The number that actually matters: how long the user stared at the launch
            // screen. Everything before it — dyld, `App.init`, the app delegate — is
            // time with nothing on screen.
            .onAppear { LaunchMetrics.mark("firstFrame") }
    }

    @ViewBuilder
    private var content: some View {
        // The other end of the bracket: the gap from here to `firstFrame` is the
        // cost of building and rendering the first screen, custom font registration
        // included.
        let _ = LaunchMetrics.markOnce("contentBody")

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
    @Environment(\.requestReview) private var requestReview

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
        .task { await askForReviewIfArmed() }
    }

    /// Presents the App Store rating sheet when onboarding armed one.
    ///
    /// `pending` lives in memory, so this can only fire in the session that armed it — a
    /// later cold launch lands here with nothing to drain.
    ///
    /// The delay is not cosmetic. This runs as the tab bar appears, which is the moment the
    /// `onboarding_complete` paywall is dismissing, and iOS drops a review request made
    /// while another sheet still owns the slot — silently, and it still counts against the
    /// three-per-year budget. `consumePending` re-checks the paywall cooldown and keeps the
    /// arm if it is still inside it, so a user who saw a paywall is asked at their first
    /// scan result instead of not at all.
    private func askForReviewIfArmed() async {
        try? await Task.sleep(for: .seconds(2.5))
        guard !Task.isCancelled, ReviewPrompt.consumePending() else { return }
        // The decision above still runs under UI testing; only the sheet is withheld. It is
        // a system alert, and onboarding arms this on the exact flow `testAHA_OnboardingFlow`
        // walks — presenting it would steal whichever tap landed 2.5s after the tab bar.
        guard !PetScansApp.isUITesting else { return }
        requestReview()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Scan.self, inMemory: true)
}

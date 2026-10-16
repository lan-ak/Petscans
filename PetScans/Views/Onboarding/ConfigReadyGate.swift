import SwiftUI
import SuperwallKit

/// Holds the first launch for up to two seconds while Superwall's config
/// downloads.
///
/// Onboarding now opens with a Superwall surface at step 1, and `register`
/// cannot present anything before config has landed — on a cold install it
/// would fire `onSkip` and drop every new user onto the native fallback. That
/// would be invisible in testing (config is cached after the first run) and
/// near-universal in production, which is the worst combination: the surface
/// would look like it worked and almost nobody would see it.
///
/// Deliberately *not* a fixed two-second sleep. It resolves the moment config
/// is ready — usually a few hundred milliseconds on a decent connection — and
/// two seconds is only the ceiling for a slow or absent network. Nobody waits
/// longer than they have to, and nobody waits forever on a plane.
///
/// Only on install. `ContentView` renders this inside the onboarding branch,
/// which by definition runs once.
struct ConfigReadyGate<Content: View>: View {
    /// The ceiling. Past this we proceed regardless and let the fallback do
    /// its job — a slow network must not become a blocked app.
    private static var timeout: Duration { .seconds(2) }

    /// How often to re-check. `configurationStatus` is a plain property with
    /// no publisher on this SDK version, so this polls rather than observes.
    private static var pollInterval: Duration { .milliseconds(50) }

    @ViewBuilder let content: () -> Content

    @State private var isReady = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isReady {
                content()
                    .transition(.opacity)
            } else {
                splash
                    .transition(.opacity)
            }
        }
        .task {
            await waitForConfig()
            withAnimation(reduceMotion ? .none : AnimationTokens.springStandard) {
                isReady = true
            }
        }
    }

    /// The launch screen, continued. Same mark and ground as
    /// `LaunchScreen`, so the hand-off from the system launch image is a
    /// cross-fade of identical pixels rather than a visible second screen.
    private var splash: some View {
        ZStack {
            ColorTokens.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.md) {
                PetScansLogo(size: .large, showText: true)

                ProgressView()
                    .tint(ColorTokens.brandPrimary)
                    .padding(.top, SpacingTokens.xs)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading PetScans")
        .accessibilityIdentifier("config-ready-gate")
    }

    private func waitForConfig() async {
        // Nothing to wait for when the SDK was never configured — UI tests
        // launch with `-UITesting`, which skips `Superwall.configure`
        // entirely, and a two-second hold on every test run buys nothing.
        guard SuperwallSafe.isReady else { return }

        let deadline = ContinuousClock.now + Self.timeout
        while ContinuousClock.now < deadline {
            if Superwall.shared.configurationStatus == .configured { return }
            try? await Task.sleep(for: Self.pollInterval)
            if Task.isCancelled { return }
        }
    }
}

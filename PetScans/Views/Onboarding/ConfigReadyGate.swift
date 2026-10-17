import SwiftUI
import SuperwallKit

/// The first thing a new install shows: the dog and cat hopping for two and a
/// half seconds while Superwall's config downloads.
///
/// Onboarding opens with a Superwall surface, and `register` cannot present
/// anything before config has landed — on a cold install it would fire
/// `onSkip` and drop every new user onto the native fallback. That would be
/// invisible in testing (config is cached after the first run) and
/// near-universal in production, which is the worst combination: the surface
/// would look like it worked and almost nobody would see it.
///
/// A fixed hold rather than "until config is ready". The surface also needs
/// its products and prices, and the splash is a beat of its own rather than a
/// loading state — ending it at a different moment on every install read as a
/// stall. Two and a half seconds is the hold *and* the ceiling: past it we
/// proceed regardless and let the fallback do its job, so a slow network never
/// becomes a blocked app.
///
/// Once per install. `ContentView` renders this inside the onboarding branch,
/// which only runs until `hasCompletedOnboarding` is set.
struct ConfigReadyGate<Content: View>: View {
    private static var hold: Duration { .milliseconds(2500) }

    @ViewBuilder let content: () -> Content

    @State private var isReady = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isReady {
                content()
                    .transition(.opacity)
            } else {
                LaunchSplash()
                    .transition(.opacity)
            }
        }
        .task {
            await waitForConfig()
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.32)) {
                isReady = true
            }
        }
    }

    private func waitForConfig() async {
        // Nothing to wait for when the SDK was never configured — UI tests
        // launch with `-UITesting`, which skips `Superwall.configure`
        // entirely, and a hold on every test run buys nothing.
        guard SuperwallSafe.isReady else { return }
        let deadline = ContinuousClock.now + Self.hold

        // Spend the hold building the surface, not just fetching config.
        // Preload-all is off at configure for launch speed, so without this the
        // splash would fade straight into Superwall's loading skeleton while the
        // webview spins up. The SDK waits for config itself before preloading.
        SuperwallSafe.preload(placements: ["onboarding_flow"])

        try? await Task.sleep(until: deadline, clock: .continuous)
    }
}

// MARK: - The splash

/// The app's own companions hopping in turn over the wordmark, with a trail of
/// three paws stepping as the loading indicator. Same ground as `LaunchScreen`,
/// so the hand-off from the system launch image is a cross-fade, not a flash.
///
/// Under Reduce Motion the pets simply sit there; the hold still runs, because
/// it is for loading, not for show.
private struct LaunchSplash: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var wordmarkIn = false

    private let dogHeight: CGFloat = 96
    /// The cat rig is drawn lighter than the dog, so it needs ~7% more height to
    /// carry the same visual mass beside it.
    private let catHeight: CGFloat = 103

    var body: some View {
        ZStack {
            ColorTokens.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                TimelineView(.animation(paused: reduceMotion)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    HStack(alignment: .bottom, spacing: SpacingTokens.xs) {
                        HoppingCompanion(
                            species: .dog,
                            height: dogHeight,
                            entranceDelay: 0,
                            hop: reduceMotion ? .rest : Hop.at(elapsed - 0.6)
                        )
                        // Half a cycle behind: one is always landing as the
                        // other leaves the ground.
                        HoppingCompanion(
                            species: .cat,
                            height: catHeight,
                            entranceDelay: 0.12,
                            hop: reduceMotion ? .rest : Hop.at(elapsed - 0.6 - Hop.period / 2)
                        )
                    }
                }

                Text("PetScans")
                    .font(TypographyTokens.displayMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .opacity(wordmarkIn ? 1 : 0)
                    .offset(y: wordmarkIn ? 0 : 8)

                PawTrail(start: start, isStill: reduceMotion)
            }
            // A hair more room below than above: the optical centre.
            .padding(.bottom, SpacingTokens.xl)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading PetScans")
        .accessibilityIdentifier("config-ready-gate")
        .onAppear {
            start = .now
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.42).delay(0.26)) {
                wordmarkIn = true
            }
        }
    }
}

/// One pose of the hop: lift in points, and the squash/stretch that sells it.
private struct Hop {
    var lift: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1

    static let rest = Hop()
    static let period: TimeInterval = 1.1
    static let height: CGFloat = 24

    /// Crouch, take off, hang, land with a squash, settle, then rest for the
    /// last quarter of the cycle so the two animals read as taking turns.
    static func at(_ time: TimeInterval) -> Hop {
        guard time > 0 else { return .rest }
        let t = time.truncatingRemainder(dividingBy: period) / period

        func mix(_ a: CGFloat, _ b: CGFloat, _ k: CGFloat) -> CGFloat { a + (b - a) * k }
        func easeOut(_ k: CGFloat) -> CGFloat { 1 - (1 - k) * (1 - k) }
        func easeIn(_ k: CGFloat) -> CGFloat { k * k }

        switch t {
        case ..<0.12:
            let k = CGFloat(t / 0.12)
            return Hop(lift: 0, scaleX: mix(1, 1.06, k), scaleY: mix(1, 0.93, k))
        case ..<0.42:
            let k = easeOut(CGFloat((t - 0.12) / 0.30))
            return Hop(lift: height * k, scaleX: mix(1.06, 0.97, k), scaleY: mix(0.93, 1.04, k))
        case ..<0.64:
            let k = easeIn(CGFloat((t - 0.42) / 0.22))
            return Hop(lift: height * (1 - k), scaleX: mix(0.97, 1.05, k), scaleY: mix(1.04, 0.95, k))
        case ..<0.76:
            let k = CGFloat((t - 0.64) / 0.12)
            return Hop(lift: 0, scaleX: mix(1.05, 1, k), scaleY: mix(0.95, 1, k))
        default:
            return .rest
        }
    }
}

/// A companion in the air, over a shadow that stays on the ground and shrinks
/// as it rises. The rig's own contact shadow is off, since it would hop too.
private struct HoppingCompanion: View {
    let species: Species
    let height: CGFloat
    let entranceDelay: Double
    let hop: Hop

    var body: some View {
        let rise = hop.lift / Hop.height
        VStack(spacing: -6) {
            CompanionView(
                species: species,
                height: height,
                entranceDelay: entranceDelay,
                showsContactShadow: false
            )
            .scaleEffect(x: hop.scaleX, y: hop.scaleY, anchor: .bottom)
            .offset(y: -hop.lift)

            Ellipse()
                .fill(ColorTokens.contactShadow)
                .frame(width: height * 0.6, height: 9)
                .blur(radius: 3)
                .scaleEffect(1 - 0.4 * rise)
                .opacity(1 - 0.55 * rise)
        }
    }
}

/// Three paws lighting in turn — the loading indicator.
private struct PawTrail: View {
    let start: Date
    let isStill: Bool

    var body: some View {
        TimelineView(.animation(paused: isStill)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .rotationEffect(.degrees(index == 1 ? 10 : -14))
                        .offset(y: index == 1 ? -3 : 3)
                        .opacity(isStill ? 0.6 : Self.opacity(elapsed - 0.4 - Double(index) * 0.2))
                }
            }
        }
    }

    /// Dim, bright at a third of the way through each 1.2 s cycle, dim again.
    private static func opacity(_ time: TimeInterval) -> Double {
        guard time > 0 else { return 0.2 }
        let t = time.truncatingRemainder(dividingBy: 1.2) / 1.2
        let peak = t < 0.35 ? t / 0.35 : (t < 0.7 ? 1 - (t - 0.35) / 0.35 : 0)
        return 0.2 + 0.8 * peak
    }
}

#Preview {
    ConfigReadyGate { Text("Onboarding") }
}

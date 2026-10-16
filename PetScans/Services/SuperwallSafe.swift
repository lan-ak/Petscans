import Foundation
import SuperwallKit

/// The app's only entry point to Superwall. Nothing outside this type should
/// touch `Superwall.shared`.
///
/// `Superwall.shared` is not a no-op before `Superwall.configure` — reading it
/// calls `assertionFailure`, so a debug build dies on that line
/// (`Superwall.swift:354`). Configure runs in `AppDelegate.didFinishLaunching`,
/// which is skipped entirely when launched with `-UITesting`. It normally lands
/// before any UI, but anything that could fire before it — onboarding's first
/// frame, an instant catalog hit — crashes without this guard.
@MainActor
enum SuperwallSafe {
    /// `Superwall.isInitialized` flips to true inside `configure`, so this is
    /// the SDK's own answer rather than a flag this app has to keep in sync.
    static var isReady: Bool { Superwall.isInitialized }

    /// False until configured. `subscriptionStatus.isActive` rather than
    /// matching `.active(_)`, whose set can hold lapsed entitlements.
    static var isSubscribed: Bool {
        isReady && Superwall.shared.subscriptionStatus.isActive
    }

    static func setUserAttributes(_ attributes: [String: Any]) {
        guard isReady else { return }
        Superwall.shared.setUserAttributes(attributes)
    }

    /// Preloads the paywalls attached to specific placements, on demand.
    ///
    /// Automatic preload-all is disabled at `configure` (it built a WebView for
    /// every paywall in every campaign at launch, saturating the main thread for
    /// seconds). Callers preload the one or two paywalls they're about to need,
    /// off the launch critical path. If Superwall isn't ready yet this no-ops and
    /// the paywall simply builds lazily on the first `register` — no user stranded.
    static func preload(placements: Set<String>) {
        guard isReady else { return }
        Superwall.shared.preloadPaywalls(forPlacements: placements)
    }

    static func register(placement: String, params: [String: Any]? = nil) {
        guard isReady else { return }
        Superwall.shared.register(placement: placement, params: params)
    }

    /// Gated variant. When Superwall is unavailable the feature still runs —
    /// the same thing the SDK does when a placement has no campaign attached, so
    /// a paywall that cannot load never strands the user on the screen behind it.
    static func register(
        placement: String,
        params: [String: Any]? = nil,
        feature: @escaping () -> Void
    ) {
        guard isReady else {
            feature()
            return
        }
        Superwall.shared.register(placement: placement, params: params, feature: feature)
    }

    /// Gated variant that also takes a presentation handler.
    ///
    /// Needed by any placement presenting a *surface* rather than a paywall —
    /// the handler is the only way to attach `onCustomCallback`, which is how
    /// a code-first screen asks the app to do something (search the bundled
    /// catalogue, open the scanner, score a product).
    ///
    /// `onSkip` matters as much as the callbacks: it fires when no paywall is
    /// shown at all (no campaign, no audience match, a load failure), and a
    /// caller replacing a native screen has to be able to tell that apart from
    /// "the user finished" so it can fall back rather than skip the step.
    static func register(
        placement: String,
        params: [String: Any]? = nil,
        handler: PaywallPresentationHandler,
        feature: @escaping () -> Void
    ) {
        guard isReady else {
            // Same contract as above: the feature runs so nobody is stranded.
            // The caller sees no `onSkip`, which is why callers must treat
            // "feature ran, handler never fired" as the fallback case too.
            feature()
            return
        }
        Superwall.shared.register(
            placement: placement,
            params: params,
            handler: handler,
            feature: feature
        )
    }
}

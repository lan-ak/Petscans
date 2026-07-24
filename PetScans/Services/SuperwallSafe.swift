import Foundation
import SuperwallKit

/// The app's only entry point to Superwall. Nothing outside this type should
/// touch `Superwall.shared`.
///
/// `Superwall.shared` is not a no-op before `Superwall.configure` — reading it
/// calls `assertionFailure`, so a debug build dies on that line
/// (`Superwall.swift:354`). Configure runs in `PetScansApp.deferredInit()`,
/// which is skipped entirely when launched with `-UITesting` and, on a normal
/// launch, completes asynchronously behind the splash screen. Anything that
/// fires before it lands — onboarding's first frame, an instant catalog hit —
/// crashes without this guard.
@MainActor
enum SuperwallSafe {
    /// `Superwall.isInitialized` flips to true inside `configure`, so this is
    /// the SDK's own answer rather than a flag this app has to keep in sync.
    static var isReady: Bool { Superwall.isInitialized }

    static func setUserAttributes(_ attributes: [String: Any]) {
        guard isReady else { return }
        Superwall.shared.setUserAttributes(attributes)
    }

    static func register(placement: String, params: [String: Any]? = nil) {
        guard isReady else { return }
        ReviewPrompt.noteSuperwallRegister()
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
        ReviewPrompt.noteSuperwallRegister()
        Superwall.shared.register(placement: placement, params: params, feature: feature)
    }
}

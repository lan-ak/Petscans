import Foundation
import SuperwallKit

/// The one rule: nobody scans or searches for their own food until a paywall
/// has actually been on screen.
///
/// Every way into scanning goes through `unlock`: the Scan tab, and the
/// onboarding surface's scan and search callbacks. Onboarding itself no longer
/// offers either. Its demo is a pick from `DemoFoods`, so the first time anyone
/// points the camera at their own bag is after `onboarding_complete` has shown
/// its paywall.
///
/// "Seen" means a paywall that sells something opened, as reported by the SDK
/// (`noteOpened`, wired in `SuperwallAttributionDelegate`). It is not "a
/// placement was registered". Registering is what `SuperwallSafe` already does
/// on every path, including the ones where nothing is shown: no config yet,
/// a paywall that failed to load, a user who killed the app before the end of
/// onboarding and came back on a build that skipped it. Those were the leaks.
/// Recording the open itself means every one of them is caught at the first
/// scan instead.
///
/// It fails open, once per launch. When `scan_gate` runs its feature without
/// presenting anything, the scanner opens for this session only and the gate
/// tries again on the next launch. Two kinds of user get there: subscribers,
/// who match no audience because every audience requires no active
/// entitlement, which is correct; and anyone the SDK cannot reach (offline,
/// config not downloaded). The catalogue is bundled, so offline scanning works
/// and fail-closed would lock those users out of the whole app with no way to
/// pay. `trigger_fire` for `scan_gate` records which case each pass was.
@MainActor
enum PaywallGate {
    /// Must sit in a campaign whose audiences cover every non-subscriber,
    /// or it is the leak this type exists to close. It shares campaign 64348
    /// with `onboarding_complete`, so the gate shows the same paywalls.
    static let placement = "scan_gate"

    private enum Key {
        static let seenAt = "paywallGate.seenAt"
    }

    /// Set when the gate let someone through without a paywall. Memory only,
    /// deliberately: persisting it would turn one bad network moment into a
    /// permanent bypass.
    private static var passedThisSession = false
    private static var inFlight = false

    static var hasSeenPaywall: Bool {
        UserDefaults.standard.object(forKey: Key.seenAt) != nil
    }

    /// Whether the scanner may open right now.
    ///
    /// Open under `-UITesting`: Superwall is never configured there, and the
    /// screenshot and onboarding tests drive the scanner directly.
    ///
    /// Open for subscribers without asking `scan_gate`, which would only find
    /// that out after the config download, with the locked screen up.
    static var isOpen: Bool {
        hasSeenPaywall || passedThisSession || SuperwallSafe.isSubscribed
            || PetScansApp.isUITesting
    }

    /// Called for every `paywallOpen` the SDK reports, from any placement.
    ///
    /// A surface with no products does not count. The onboarding flow
    /// (`onboarding_flow`, paywall 275901) is presented through the same
    /// pipeline and fires the same event, but sells nothing; counting it
    /// would let the surface itself open the gate.
    static func noteOpened(_ info: PaywallInfo) {
        guard !info.productIds.isEmpty else { return }
        UserDefaults.standard.set(Date(), forKey: Key.seenAt)
    }

    /// Runs `proceed` once the user may scan their own food, presenting a
    /// paywall first if they have never seen one.
    ///
    /// `proceed` runs at most once per call. It does not run if a gated
    /// paywall is closed without a purchase. The caller stays locked, and the
    /// next call finds `hasSeenPaywall` set and goes straight through, so a
    /// second tap is never another paywall.
    static func unlock(source: String, proceed: @escaping @MainActor () -> Void) {
        if isOpen {
            proceed()
            return
        }
        guard !inFlight else { return }
        inFlight = true

        var finished = false
        let finish: @MainActor () -> Void = {
            guard !finished else { return }
            finished = true
            inFlight = false
            // Through without a paywall: a subscriber, or the SDK could
            // not present. Either way, this launch only.
            if !hasSeenPaywall { passedThisSession = true }
            proceed()
        }

        let handler = PaywallPresentationHandler()
        // Belt and braces with the delegate: the open is recorded before the
        // user can dismiss, whichever of the two lands first.
        handler.onPresent { info in
            Task { @MainActor in noteOpened(info) }
        }
        handler.onDismiss { _, _ in
            Task { @MainActor in inFlight = false }
        }
        handler.onError { _ in
            Task { @MainActor in finish() }
        }

        SuperwallSafe.register(
            placement: placement,
            params: ["source": source],
            handler: handler
        ) {
            Task { @MainActor in finish() }
        }
    }
}

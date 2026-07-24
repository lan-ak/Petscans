import AppTrackingTransparency
import FacebookCore
import Foundation
import UIKit

/// Meta (Facebook) SDK: install attribution and ad-campaign event tracking.
///
/// Two values must be filled into Info.plist before this does anything useful —
/// `FacebookAppID` and `FacebookClientToken`, plus the matching `fb<APP-ID>` URL
/// scheme. Both come from developers.facebook.com (Settings → Basic and
/// Settings → Advanced). They are client-side identifiers, not secrets: unlike
/// the provider keys behind the API proxy, Meta requires these compiled into the
/// binary, and every app that ships the SDK exposes them.
///
/// Attribution only works if the SDK is initialized during
/// `didFinishLaunchingWithOptions` — Meta matches the install against the ad
/// click using launch context, so a later init silently loses attribution.
enum AttributionService {

    /// Whether real Meta credentials have been filled into Info.plist.
    ///
    /// Until they are, every entry point below no-ops. Without this the SDK would
    /// initialize with the literal `REPLACE-WITH-…` strings, ship failing requests
    /// to Meta on every launch, and — worse — put the ATT prompt in front of users
    /// to collect an identifier that nothing is listening for. Keeping the
    /// integration inert means an unconfigured build behaves exactly like one
    /// without the SDK at all.
    private static var isConfigured: Bool {
        func value(_ key: String) -> String? {
            Bundle.main.object(forInfoDictionaryKey: key) as? String
        }
        guard let appID = value("FacebookAppID"),
              let clientToken = value("FacebookClientToken"),
              !appID.isEmpty, !clientToken.isEmpty,
              !appID.hasPrefix("REPLACE-"), !clientToken.hasPrefix("REPLACE-")
        else { return false }
        return true
    }

    /// True when the SDK should be driven at all: real credentials, and not a UI test.
    private static var isEnabled: Bool {
        !PetScansApp.isUITesting && isConfigured
    }

    /// Initializes the Meta SDK. Must be called from
    /// `application(_:didFinishLaunchingWithOptions:)`, not from a Task.
    static func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard isEnabled else { return }

        // `Settings.shared.isAdvertiserTrackingEnabled` used to be seeded here from
        // `ATTrackingManager.trackingAuthorizationStatus`, so a user who granted ATT
        // on an earlier launch was authorized from this launch's first event rather
        // than only after requestTrackingAuthorization() re-confirmed. As of FBSDK 18
        // the setter is deprecated and ignored — the SDK reads ATT status itself,
        // which is exactly the behaviour that seeding was reaching for — and calling
        // it only emitted a deprecation warning on every launch.
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: launchOptions
        )
    }

    /// Shows the iOS tracking prompt. Meta picks the result up on its own — the SDK
    /// reads `ATTrackingManager` directly, so there is nothing to hand it here.
    ///
    /// Without an `.authorized` result Meta gets no IDFA and attribution degrades
    /// to SKAdNetwork (aggregated, delayed, campaign-level only) — that is the
    /// expected floor, not a failure.
    ///
    /// iOS only shows the prompt while the app is active, and only once per
    /// install; on every later launch this returns the cached status without
    /// showing UI, so it is safe to call unconditionally on each launch.
    @MainActor
    static func requestTrackingAuthorization() async {
        guard isEnabled else { return }

        _ = await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Routes an incoming URL to Meta for deferred deep links and ad referrals.
    /// Returns whether Meta claimed the URL, so other handlers can be skipped.
    @discardableResult
    static func handleDeepLink(_ url: URL) -> Bool {
        guard isEnabled else { return false }

        return ApplicationDelegate.shared.application(
            UIApplication.shared,
            open: url,
            options: [:]
        )
    }

    /// Logs the foreground. Must be driven from SwiftUI's `scenePhase`: this app is
    /// scene-based (`UIApplicationSceneManifest`), so UIKit routes lifecycle to the
    /// scene and `UIApplicationDelegate.applicationDidBecomeActive` is never called.
    static func logAppActivation() {
        guard isEnabled else { return }
        AppEvents.shared.activateApp()
    }

    // MARK: - Conversion events

    /// Meta optimizes ad delivery against these, so they need to fire in the app
    /// even though the purchase itself is Superwall's. Driven by
    /// `SuperwallAttributionDelegate`, which maps `.subscriptionStart` and
    /// `.freeTrialStart` onto the two calls below.

    /// A completed subscription purchase, the primary optimization event.
    static func logSubscription(amount: Decimal, currency: String) {
        guard isEnabled else { return }

        AppEvents.shared.logEvent(
            .subscribe,
            valueToSum: NSDecimalNumber(decimal: amount).doubleValue,
            parameters: [.currency: currency]
        )
    }

    /// A started free trial.
    static func logStartTrial(amount: Decimal, currency: String) {
        guard isEnabled else { return }

        AppEvents.shared.logEvent(
            .startTrial,
            valueToSum: NSDecimalNumber(decimal: amount).doubleValue,
            parameters: [.currency: currency]
        )
    }

    /// A completed scan — the app's core activation moment, useful as a
    /// top-of-funnel signal for campaigns that optimize on engagement.
    static func logScanCompleted() {
        guard isEnabled else { return }
        AppEvents.shared.logEvent(AppEvents.Name("ScanCompleted"))
    }
}

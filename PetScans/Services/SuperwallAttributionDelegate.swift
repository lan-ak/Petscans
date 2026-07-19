import Foundation
import SuperwallKit

/// Bridges Superwall's purchase lifecycle to Meta ad-campaign conversion events.
///
/// Purchases happen entirely inside Superwall paywalls, so the app never sees a
/// StoreKit transaction of its own — this delegate is the only place it learns that
/// a trial started or a subscription began. Meta optimizes ad delivery against these
/// two events, so forwarding them is what lets a campaign learn which ads produce
/// paying users.
///
/// Trial start and subscription start are forwarded on **distinct** Superwall events
/// (`.freeTrialStart` vs `.subscriptionStart`), so a trial that later converts to
/// paid is not counted as two purchases. Every forwarded call no-ops unless Meta
/// credentials are configured (see `AttributionService`).
final class SuperwallAttributionDelegate: SuperwallDelegate {

    /// Superwall retains its delegate weakly, so the app must hold this instance.
    static let shared = SuperwallAttributionDelegate()

    private init() {}

    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        switch eventInfo.event {
        case let .freeTrialStart(product, _):
            AttributionService.logStartTrial(
                amount: product.price,
                currency: product.currencyCode ?? ""
            )
        case let .subscriptionStart(product, _):
            AttributionService.logSubscription(
                amount: product.price,
                currency: product.currencyCode ?? ""
            )
        default:
            break
        }
    }
}

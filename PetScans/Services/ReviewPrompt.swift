import Foundation
import StoreKit
import SwiftUI

/// Decides when to ask for an App Store rating.
///
/// The app shipped four versions without ever asking, which is why it sits at
/// zero ratings. Asking is cheap; asking at the wrong moment is not — iOS caps
/// the prompt at three per year per user and silently swallows every request
/// past that, so a badly-timed ask burns one of three chances for the year.
///
/// Eligibility is recorded on the model side (`ScannerViewModel.computeScore`)
/// because that is the one funnel every scan passes through. Presenting has to
/// happen from a `View` — `requestReview` is a SwiftUI environment action — so
/// the decision is stored here and drained by `ProductScoreView` on appear.
@MainActor
enum ReviewPrompt {

    // MARK: - Tuning

    /// Scans a user must complete before the first ask. Two is still someone
    /// evaluating the app; by three they have chosen to keep using it.
    private static let minimumScans = 3

    /// iOS allows three prompts a year. Asking every four months means a user
    /// who declines is not badgered, and one who upgrades hardware mid-year
    /// still gets a chance on the new device.
    private static let minimumDaysBetweenPrompts = 120

    /// A paywall and a rating request are both interruptions. Back to back they
    /// read as a shakedown, and the rating is the one that gets dismissed.
    private static let paywallCooldown: TimeInterval = 60

    // MARK: - Storage

    private enum Key {
        static let lastPromptedAt = "reviewPrompt.lastPromptedAt"
        static let lastPaywallAt = "reviewPrompt.lastPaywallAt"
        static let sessionCount = "reviewPrompt.sessionCount"
    }

    private static var pending = false

    // MARK: - Signals in

    /// Called once per cold launch. A user across two sessions has come back on
    /// purpose; a user still inside their first session has not decided anything
    /// yet, however many things they scanned.
    static func recordSessionStart() {
        let count = UserDefaults.standard.integer(forKey: Key.sessionCount)
        UserDefaults.standard.set(count + 1, forKey: Key.sessionCount)
    }

    /// Called from `SuperwallAttributionDelegate` on `paywallOpen` — a paywall the
    /// user actually saw.
    ///
    /// This used to be called from `SuperwallSafe.register` instead, on the theory
    /// that any placement *might* present a paywall. It does not: `register` fires
    /// for every placement regardless of whether a campaign matches. Since
    /// `analysis_complete` registers on every scan immediately after the prompt is
    /// armed, `lastPaywallAt` was always ~2.5s old by the time the result screen
    /// drained it, and `consumePending` cancelled the ask every time.
    static func notePaywallPresented() {
        UserDefaults.standard.set(Date(), forKey: Key.lastPaywallAt)
    }

    /// Called when a scan finishes scoring. Arms the prompt only if this was a
    /// good moment — see `isGoodMoment`.
    static func recordScanCompleted(breakdown: ScoreBreakdown, analysisCount: Int) {
        guard isGoodMoment(breakdown: breakdown, analysisCount: analysisCount) else { return }
        pending = true
    }

    // MARK: - Signals out

    /// Drains the armed flag. Returns true at most once per armed scan, so a
    /// result screen that gets re-rendered does not ask twice.
    static func consumePending() -> Bool {
        guard pending else { return false }
        pending = false
        // Re-check the paywall cooldown here rather than only at arming time:
        // `analysis_complete` registers after the score is computed, so the
        // paywall this scan may trigger lands *between* arming and presenting.
        guard !isWithinPaywallCooldown else { return false }
        UserDefaults.standard.set(Date(), forKey: Key.lastPromptedAt)
        return true
    }

    // MARK: - Rules

    private static func isGoodMoment(breakdown: ScoreBreakdown, analysisCount: Int) -> Bool {
        guard analysisCount >= minimumScans else { return false }
        guard UserDefaults.standard.integer(forKey: Key.sessionCount) >= 2 else { return false }

        // Only on an instant catalog hit. That is the path 1.4.x made fast, and
        // it is the only one where the user has just watched the app work
        // exactly as advertised. OCR and web paths involve waiting and can be
        // wrong; neither is a moment to ask for five stars.
        guard breakdown.scoreSource == .databaseVerified else { return false }

        // Never ask someone who has just been told their pet's food is unsafe.
        // The information is the product working correctly, but the feeling is
        // not one that produces a good review.
        guard breakdown.ratingLabel == .excellent || breakdown.ratingLabel == .good else { return false }

        guard !isWithinPaywallCooldown else { return false }
        guard !isWithinPromptCooldown else { return false }

        return true
    }

    private static var isWithinPaywallCooldown: Bool {
        guard let last = UserDefaults.standard.object(forKey: Key.lastPaywallAt) as? Date else {
            return false
        }
        return Date().timeIntervalSince(last) < paywallCooldown
    }

    private static var isWithinPromptCooldown: Bool {
        guard let last = UserDefaults.standard.object(forKey: Key.lastPromptedAt) as? Date else {
            return false
        }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? .max
        return days < minimumDaysBetweenPrompts
    }
}

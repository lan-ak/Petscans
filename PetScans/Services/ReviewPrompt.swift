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

    /// How long an armed-but-unasked moment stays worth honouring.
    ///
    /// The arm used to live in memory, so it died with the session that made it. That
    /// was the single largest leak in the whole mechanism: onboarding ends by presenting
    /// a paywall, `consumePending` defers for `paywallCooldown` — and by the time the
    /// deferral lifts, most users have closed the app. The arm evaporated and they were
    /// never asked at all.
    ///
    /// It persists now, but not forever. Inside a week the onboarding is still what the
    /// user remembers about this app; past that a real scan result is a better moment
    /// than a cold launch with no context, and `isGoodMoment` is already watching for one.
    private static let armLifetime: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Storage

    private enum Key {
        static let lastPromptedAt = "reviewPrompt.lastPromptedAt"
        static let lastPaywallAt = "reviewPrompt.lastPaywallAt"
        static let sessionCount = "reviewPrompt.sessionCount"
        static let armedAt = "reviewPrompt.armedAt"
    }

    /// Whether a moment worth asking on is currently armed.
    ///
    /// Stored as the *time* it was armed rather than a flag, so persistence and expiry
    /// are the same field: an arm older than `armLifetime` simply stops reading as one.
    private static var pending: Bool {
        get {
            guard let armed = UserDefaults.standard.object(forKey: Key.armedAt) as? Date else {
                return false
            }
            return Date().timeIntervalSince(armed) < armLifetime
        }
        set {
            if newValue {
                UserDefaults.standard.set(Date(), forKey: Key.armedAt)
            } else {
                UserDefaults.standard.removeObject(forKey: Key.armedAt)
            }
        }
    }

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
        // Re-check the paywall cooldown here rather than only at arming time:
        // `analysis_complete` registers after the score is computed, so the
        // paywall this scan may trigger lands *between* arming and presenting.
        //
        // The arm is deliberately **not** cleared when this is what blocks it. The moment
        // was already judged worth asking on, and burning it because a paywall happened to
        // land first spends the arm on nothing — the next result screen is a better place
        // for it. This is also what lets an onboarding arm survive the paywall that
        // `onboarding_complete` itself presents.
        guard !isWithinPaywallCooldown else { return false }
        pending = false
        UserDefaults.standard.set(Date(), forKey: Key.lastPromptedAt)
        return true
    }

    /// Arms the ask for a user who has just finished onboarding.
    ///
    /// No pre-prompt: the system sheet is the ask. What stands in for sentiment is that they
    /// walked the whole flow — named their pet, picked what to avoid, and stayed for the
    /// personalised verdict on a food they chose themselves. Someone who skipped to the end
    /// is not asked.
    ///
    /// The volume gates in `isGoodMoment` (three analyses, two cold launches) deliberately do
    /// not apply. They exist to prove intent before spending one of Apple's three prompts a
    /// year, and finishing onboarding proves it a different way — but they are also why the
    /// app shipped four versions with one rating, since most users never reach a second
    /// session. The cooldowns still apply, and the paywall interlock above still defers.
    static func recordOnboardingCompleted(sawPersonalizedResult: Bool) {
        guard sawPersonalizedResult, !isWithinPromptCooldown else { return }
        pending = true
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

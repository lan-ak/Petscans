import Foundation

/// Stores the avoidance groups picked during onboarding.
///
/// Device-level rather than per-pet on purpose: "Skip for now" finishes
/// onboarding without creating a `Pet`, and that cohort is exactly the one worth
/// addressing on the paywall. Hanging the answer off `Pet` would drop it for
/// every user who skipped.
///
/// Read on every scan: `Matching+SharedDatabase` defaults its `avoidanceGroups`
/// argument to this value, so changing it changes scores app-wide. See
/// `AvoidanceGroup`. Note there is currently no edit surface in Settings — once set
/// in onboarding a user cannot change their watch list.
enum AvoidancePreferences {
    private static let key = "avoidanceGroups"

    static var groups: Set<AvoidanceGroup> {
        get {
            let raw = UserDefaults.standard.stringArray(forKey: key) ?? []
            return Set(raw.compactMap(AvoidanceGroup.init(rawValue:)))
        }
        set {
            // Sorted by the enum's own case order so the stored value — and the
            // `avoid_groups` attribute derived from it — is stable across
            // launches rather than reshuffling with Set ordering.
            let ordered = AvoidanceGroup.allCases
                .filter(newValue.contains)
                .map(\.rawValue)
            UserDefaults.standard.set(ordered, forKey: key)
        }
    }
}

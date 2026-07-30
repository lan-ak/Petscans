import Foundation

enum RuleSeverity: String, Codable, CaseIterable {
    case info
    case warn
    case high
    case critical

    /// Unknown raw values decode to `.warn` rather than throwing.
    ///
    /// `RuleSeverity` is persisted inside `WarningFlag`, which is persisted inside
    /// `ScoreBreakdown.flags`. Throwing here would drop the *entire* flags array of a
    /// saved scan — including its allergen and toxicity warnings — so a future
    /// severity tier could silently hide safety information from an older build.
    /// `.warn` is the deliberate choice over `.info`: an unrecognised severity should
    /// stay visible, not be demoted to a footnote. Mirrors `WarningType.init(from:)`.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RuleSeverity(rawValue: raw) ?? .warn
    }

    /// Most severe first, for ordering a list of warnings. `CaseIterable` order
    /// runs the other way, so sorting on it would bury a critical warning under
    /// an informational one.
    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .warn: return 2
        case .info: return 3
        }
    }

    var displayName: String {
        switch self {
        case .info: return "Info"
        case .warn: return "Warning"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warn: return "exclamationmark.triangle"
        case .high: return "exclamationmark.circle"
        case .critical: return "xmark.octagon"
        }
    }
}

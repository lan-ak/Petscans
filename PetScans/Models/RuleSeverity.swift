import Foundation
import SwiftUI

enum RuleSeverity: String, Codable, CaseIterable {
    case info
    case warn
    case high
    case critical

    var displayName: String {
        switch self {
        case .info: return "Info"
        case .warn: return "Warning"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .info: return ColorTokens.severityInfo
        case .warn: return ColorTokens.severityWarning
        case .high: return ColorTokens.severityHigh
        case .critical: return ColorTokens.severityCritical
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

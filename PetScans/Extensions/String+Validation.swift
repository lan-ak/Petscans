import Foundation

extension String {
    /// Returns the string with leading and trailing whitespace removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }

    /// Returns true if the string contains non-whitespace characters.
    var isNotBlank: Bool {
        !trimmed.isEmpty
    }
}

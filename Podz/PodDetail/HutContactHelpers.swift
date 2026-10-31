import Foundation

/// Helpers for a listed hut's contact details (used by the detail's Contact
/// section and by Lenny's booking message).
func hutClean(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
}

/// A website without its scheme ("refuge.com") still opens.
func hutWebURL(_ link: String) -> URL? {
    URL(string: link.hasPrefix("http") ? link : "https://\(link)")
}

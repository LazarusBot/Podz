import Foundation

/// Shortens the backend's sentences ("For security purposes, you can only
/// request this after 51 seconds.") into the few words the onboarding has
/// room for. Anything unrecognized falls through unchanged rather than
/// being hidden, so a genuinely new error is never suppressed.
nonisolated enum OnboardingErrorText {
    static func short(_ message: String) -> String {
        let lower = message.lowercased()

        if lower.contains("security purposes"),
           let seconds = firstNumber(in: message, after: "after ") {
            return "Security: wait \(seconds)s"
        }
        if lower.contains("rate limit") {
            return "Too many emails, try later"
        }
        if lower.contains("expired or is invalid") || lower.contains("invalid token") {
            return "Wrong or expired code"
        }
        if lower.contains("invalid format") || lower.contains("unable to validate email") {
            return "Invalid email"
        }
        if lower.contains("error sending") {
            return "Couldn't send, try again"
        }
        if lower.contains("offline") || lower.contains("network connection") {
            return "No connection"
        }
        return message
    }

    /// The integer right after `marker`, e.g. 51 in "after 51 seconds".
    private static func firstNumber(in text: String, after marker: String) -> Int? {
        guard let range = text.range(of: marker) else { return nil }
        let digits = text[range.upperBound...].prefix(while: \.isNumber)
        return Int(digits)
    }
}

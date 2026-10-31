import Foundation

/// Whether a hut is open today, read from its opening hours when they're in a
/// shape that can be trusted: a season ("Jun-Sep", "Jun 15 - Sep 15", "Oct-May
/// off") or "24/7". Anything else (weekday hours, "by appointment") is left
/// alone: no label is better than a wrong one.
enum OpeningStatus {
    struct Result: Equatable {
        let isOpen: Bool
        /// "Open now" or "Closed until June".
        let label: String
    }

    private static let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    static func evaluate(_ raw: String?, today: Date = Date()) -> Result? {
        guard let text = hutClean(raw)?.lowercased() else { return nil }
        if text.contains("24/7") { return Result(isOpen: true, label: "Open now") }

        let names = months.joined(separator: "|")
        let pattern = "\\b(\(names))[a-z]*\\.?\\s*(?:\\d{1,2})?\\s*[-–]\\s*(\(names))[a-z]*\\.?(.{0,14})"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let startRange = Range(match.range(at: 1), in: text),
              let endRange = Range(match.range(at: 2), in: text),
              let start = months.firstIndex(of: String(text[startRange])),
              let end = months.firstIndex(of: String(text[endRange]))
        else { return nil }

        // "Oct-May off": the range is when it's closed.
        let after = Range(match.range(at: 3), in: text).map { String(text[$0]) } ?? ""
        let rangeIsClosed = after.contains("off") || after.contains("closed")

        let month = Calendar(identifier: .gregorian).component(.month, from: today) - 1
        let inRange = start <= end ? (month >= start && month <= end) : (month >= start || month <= end)
        let isOpen = rangeIsClosed ? !inRange : inRange
        if isOpen { return Result(isOpen: true, label: "Open now") }

        // The next opening is the start of the range (or the month after it
        // when the range is the closed one).
        let nextOpen = rangeIsClosed ? (end + 1) % 12 : start
        return Result(isOpen: false, label: "Closed until \(monthNames[nextOpen])")
    }
}

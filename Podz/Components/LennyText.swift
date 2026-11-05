import Foundation

/// How Lenny compares words, so a place is found however it was typed:
/// "Haute Savoie", "haute-savoie" and "HAUTE  SAVOIE" are one name, "Zermat"
/// finds "Zermatt".
nonisolated enum LennyText {
    private static let separators: Set<Unicode.Scalar> = ["-", "‐", "‑", "–", "—", "'", "’", "`", ".", "_", "/"]

    /// Lower case, without accents, and with dashes, apostrophes and dots as
    /// spaces, one for one (so a position in the result is a position in the
    /// text). Words are what's left to compare.
    static func fold(_ string: String) -> String {
        let folded = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return String(String.UnicodeScalarView(folded.unicodeScalars.map { separators.contains($0) ? " " : $0 }))
    }

    /// Case and accents only, punctuation kept ("->" stays "->").
    static func plainFold(_ string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// Built once: compiling it per call made searching thousands of names slow.
    private static let wordPattern = try! NSRegularExpression(pattern: #"[\p{L}\p{N}]+"#)

    /// The words of a folded text with where each is (UTF-16 offsets, as
    /// `NSRange` uses).
    static func words(in folded: String) -> [(word: String, range: NSRange)] {
        return wordPattern.matches(in: folded, range: NSRange(folded.startIndex..., in: folded)).compactMap { match in
            Range(match.range, in: folded).map { (String(folded[$0]), match.range) }
        }
    }

    /// Whether two words are one typo apart (a letter wrong, missing, extra, or
    /// two swapped). Names under 7 letters must match exactly: too many real
    /// words sit one letter from each other.
    static func isTypo(_ a: String, of b: String) -> Bool {
        guard b.count >= 7, a != b, abs(a.count - b.count) <= 1 else { return false }
        let x = Array(a), y = Array(b)
        if x.first != y.first { return false }
        if x.count == y.count {
            let diff = (0..<x.count).filter { x[$0] != y[$0] }
            if diff.count == 1 { return true }
            return diff.count == 2 && diff[1] == diff[0] + 1 && x[diff[0]] == y[diff[1]] && x[diff[1]] == y[diff[0]]
        }
        let (long, short) = x.count > y.count ? (x, y) : (y, x)
        var i = 0
        while i < short.count, long[i] == short[i] { i += 1 }
        return Array(long[(i + 1)...]) == Array(short[i...])
    }
}

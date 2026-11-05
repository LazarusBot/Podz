import Foundation

extension LennyText {
    /// Whether a search typed by hand finds a place, the way Lenny reads it:
    /// "haute savoi", "Haute-Savoie" and "HAUTE  SAVOIE" are one name, accents
    /// don't matter, and one wrong letter is forgiven ("Chamonx", "Haute Savoe").
    /// The words may be the start of a name too, since the list updates while
    /// you type.
    static func matches(_ query: String, in fields: [String?]) -> Bool {
        let wanted = words(in: fold(query)).map(\.word)
        guard !wanted.isEmpty else { return false }
        let phrase = wanted.joined(separator: " ")
        for field in fields.compactMap({ $0 }) {
            let text = words(in: fold(field)).map(\.word)
            guard text.count >= 1 else { continue }
            if text.joined(separator: " ").contains(phrase) { return true }
            // The same words with a typo, wherever they sit in the name.
            let size = wanted.count
            guard size <= text.count else { continue }
            for start in 0...(text.count - size) {
                let slice = text[start..<(start + size)].joined(separator: " ")
                if isTypo(phrase, of: slice) { return true }
            }
        }
        return false
    }
}

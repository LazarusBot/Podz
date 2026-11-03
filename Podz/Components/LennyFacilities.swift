import Foundation

/// The facility words people use in a search ("with showers", "drinking
/// water", "a winter room", "avec douche"), in English and French, mapped to
/// the labels the app stores in `pods.facilities`. Lenny reads them from the
/// sentence (`LennyRequestParser`) and ranks each stop's huts by them
/// (`LennySearchViewModel`).
enum LennyFacilities {
    /// (label as stored on a pod, the words for it, accents folded, lower case).
    /// Longest phrases first inside each pattern so "drinking water" wins over "water".
    private static let table: [(label: String, pattern: String)] = [
        ("Drinking water", #"drinking water|potable water|fresh water|tap water|running water|water|eau potable|eau courante|point d'eau|eau"#),
        ("Showers", #"showers?|douches?|docce|doccia"#),
        ("Winter room", #"winter (?:room|shelter|hut|refuge)|winterraum|salle d'hiver|local d'hiver|refuge d'hiver|locale invernale"#),
        ("Meals", #"meals?|food|dinner|breakfast|lunch|restaurant|half[- ]board|demi[- ]pension|repas|diner|petit[- ]dejeuner|pasti|cena"#),
        ("Self-catering", #"self[- ]catering|kitchen|cooking|cook|cuisine|cuisiner"#),
        ("Electricity", #"electricity|power outlets?|plugs?|charging|electricite|prises?"#),
        ("Wi-Fi", #"wi-?fi|internet|wlan"#),
        ("Heating", #"heating|heated|heater|chauffage|chauffe|riscaldamento"#),
        ("Toilets", #"toilets?|wc|restrooms?|toilettes?|bagni"#),
        ("Dogs welcome", #"dogs?|pets?|chiens?|cani"#),
        ("Wheelchair access", #"wheel-?chairs?|fauteuil roulant|step-free|disabled access"#)
    ]

    private static let regexes: [(label: String, regex: NSRegularExpression)] = table.compactMap { entry in
        let pattern = #"(?<![\p{L}\p{N}])(?:"# + entry.pattern + #")(?![\p{L}\p{N}])"#
        return (try? NSRegularExpression(pattern: pattern)).map { (entry.label, $0) }
    }

    /// The facilities a (folded, lower-case) sentence asks for, in the order
    /// they were said, each once.
    static func wanted(in folded: String) -> [String] {
        let whole = NSRange(folded.startIndex..., in: folded)
        var found: [(label: String, position: Int)] = []
        for (label, regex) in regexes {
            if let match = regex.firstMatch(in: folded, range: whole) {
                found.append((label, match.range.location))
            }
        }
        return found.sorted { $0.position < $1.position }.map(\.label)
    }

    /// The sentence without its facility words, to see whether a place is left.
    static func removing(from folded: String) -> String {
        var text = folded
        for (_, regex) in regexes {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }
        return text
    }

    /// "showers", "showers and drinking water", "meals, showers and toilets".
    static func phrase(_ labels: [String]) -> String {
        let names = labels.map { $0.lowercased() }
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
    }
}

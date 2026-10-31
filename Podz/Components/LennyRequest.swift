import Foundation
import NaturalLanguage

/// What Lenny understood from what the user typed: the places (in the order
/// they were said), and, when the sentence gives them, how many are going,
/// from when, and for how long. Built on the device by `LennyRequestParser`.
struct LennyRequest {
    struct Mention {
        enum Kind { case pod, region, country, place }

        let name: String
        let kind: Kind
        /// The pods the words name outright: one pod, or every pod of a region
        /// or country. Empty for a free place, which gets geocoded.
        let pods: [Pod]
        /// Where it was said, to keep the stops in the order of the sentence.
        let position: Int
    }

    var mentions: [Mention] = []
    /// A stay in days ("5 days", "a week") and in nights ("4 nights").
    var days: Int?
    var nights: Int?
    var guests: Int?
    var startDate: Date?

    /// How many nights each stop probably gets, from the stay the user gave.
    func suggestedNightsPerStop(stops: Int, maximum: Int) -> Int? {
        guard stops > 0, let total = nights ?? days, total > 0 else { return nil }
        return max(1, min(maximum, Int((Double(total) / Double(stops)).rounded())))
    }

    /// "3 guests · from Sat 31 Oct · 5 days", for what Lenny says it picked up.
    var understood: String? {
        var parts: [String] = []
        if let guests { parts.append("\(guests) \(guests == 1 ? "guest" : "guests")") }
        if let startDate { parts.append("from \(startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))") }
        if let nights { parts.append("\(nights) \(nights == 1 ? "night" : "nights")") }
        else if let days { parts.append("\(days) \(days == 1 ? "day" : "days")") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Reads a free sentence, long or messy, without a server: pods, regions and
/// countries are matched by name (accents, case and French / Italian / German
/// spellings don't matter); other places come from Apple's language tagger and
/// from capitalised names; numbers of guests, nights, days and dates come from
/// patterns in English and French. Only the first 2,000 characters are read.
enum LennyRequestParser {
    static let maxLength = 2_000
    static let maxStops = 8

    static func parse(_ raw: String, pods: [Pod]) -> LennyRequest {
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        var request = LennyRequest()
        guard !text.isEmpty else { return request }

        let known = knownMentions(in: text, pods: pods)
        var mentions = known
        mentions += freePlaces(in: text, avoiding: known)
        mentions.sort { $0.position < $1.position }

        // One word or a short phrase with nothing recognised: it is the place.
        if mentions.isEmpty {
            let words = text.split(whereSeparator: { $0.isWhitespace })
            if words.count <= 4 {
                let place = text.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
                if !place.isEmpty {
                    mentions = [.init(name: place, kind: .place, pods: [], position: 0)]
                }
            }
        }
        request.mentions = Array(mentions.prefix(maxStops))

        let folded = fold(text)
        request.guests = guests(in: folded)
        (request.days, request.nights) = stay(in: folded)
        request.startDate = startDate(in: text)
        return request
    }

    // MARK: - Pods, regions and countries by name

    private static let countryAliases: [String: String] = [
        "suisse": "Switzerland", "schweiz": "Switzerland", "svizzera": "Switzerland",
        "italie": "Italy", "italia": "Italy", "italien": "Italy",
        "autriche": "Austria", "osterreich": "Austria", "austria": "Austria",
        "allemagne": "Germany", "deutschland": "Germany",
        "slovenie": "Slovenia", "slovenija": "Slovenia",
        "espagne": "Spain", "espana": "Spain",
        "norvege": "Norway", "norge": "Norway",
        "ecosse": "Scotland", "angleterre": "England",
        "etats-unis": "United States", "usa": "United States"
    ]

    private struct Candidate {
        let name: String
        let key: String
        let kind: LennyRequest.Mention.Kind
        let pods: [Pod]
    }

    private static let podWords: Set<String> = [
        "rifugio", "refuge", "chalet", "cabane", "hut", "capanna", "koca", "baita", "hutte", "gite", "auberge", "pod"
    ]

    /// The pod's name without its leading "Rifugio" / "Refuge du": the way
    /// people say it.
    private static func withoutPodWord(_ name: String) -> String? {
        var words = name.split(separator: " ").map(String.init)
        guard words.count >= 2, podWords.contains(fold(words[0])) else { return nil }
        words.removeFirst()
        if let first = words.first, ["du", "de", "di", "des", "del", "della"].contains(fold(first)), words.count >= 2 { words.removeFirst() }
        return words.joined(separator: " ")
    }

    private static func knownMentions(in text: String, pods: [Pod]) -> [LennyRequest.Mention] {
        var candidates: [Candidate] = []
        for pod in pods {
            candidates.append(Candidate(name: pod.name, key: fold(pod.name), kind: .pod, pods: [pod]))
            // "Passo Santner" names "Rifugio Passo Santner" too.
            if let short = withoutPodWord(pod.name), fold(short) != fold(pod.name) {
                candidates.append(Candidate(name: pod.name, key: fold(short), kind: .pod, pods: [pod]))
            }
        }
        for (region, group) in Dictionary(grouping: pods.filter { !($0.region ?? "").isEmpty }, by: { $0.region ?? "" }) {
            candidates.append(Candidate(name: region, key: fold(region), kind: .region, pods: group))
        }
        let byCountry = Dictionary(grouping: pods, by: \.country)
        for (country, group) in byCountry where !country.isEmpty {
            candidates.append(Candidate(name: country, key: fold(country), kind: .country, pods: group))
        }
        for (alias, country) in countryAliases {
            if let group = byCountry[country] {
                candidates.append(Candidate(name: country, key: alias, kind: .country, pods: group))
            }
        }

        let folded = fold(text)
        let whole = NSRange(folded.startIndex..., in: folded)
        var taken: [NSRange] = []
        var found: [LennyRequest.Mention] = []
        // Longest names first, so "Refuge du Dôme" wins over "Dôme".
        for candidate in candidates.sorted(by: { $0.key.count > $1.key.count }) where candidate.key.count >= 3 {
            let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: candidate.key) + "(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: folded, range: whole),
                  !taken.contains(where: { NSIntersectionRange($0, match.range).length > 0 })
            else { continue }
            taken.append(match.range)
            found.append(.init(name: candidate.name, kind: candidate.kind, pods: candidate.pods, position: match.range.location))
        }
        return found
    }

    // MARK: - Other places

    /// Capitalised words that aren't places: the start of a sentence, days,
    /// months, pronouns and the little words of a request, in English and French.
    private static let notPlaces: Set<String> = [
        "i", "i'd", "i'm", "i'll", "we", "we'd", "we're", "my", "our", "me", "us", "hi", "hello", "hey", "please",
        "can", "could", "would", "will", "should", "from", "to", "then", "next", "after", "also", "and", "or",
        "in", "on", "for", "with", "via", "near", "around", "by", "at", "the", "a", "an", "lenny", "looking",
        "find", "need", "want", "plan", "trip", "hike", "hiking", "trek", "walk", "days", "day", "night",
        "nights", "week", "weekend", "people", "guests", "friends", "family", "thanks", "thank", "start",
        "starting", "end", "ending", "stay", "sleep", "book", "book", "pods", "pod", "hut", "huts", "refuge",
        "refuges", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "january",
        "february", "march", "april", "may", "june", "july", "august", "september", "october", "november",
        "december", "tomorrow", "today", "je", "j'aimerais", "nous", "mon", "ma", "mes", "nos", "de", "du", "des",
        "puis", "ensuite", "apres", "vers", "depuis", "pour", "avec", "et", "ou", "lundi", "mardi", "mercredi",
        "jeudi", "vendredi", "samedi", "dimanche", "janvier", "fevrier", "mars", "avril", "mai", "juin",
        "juillet", "aout", "septembre", "octobre", "novembre", "decembre", "bonjour", "salut", "svp", "merci",
        "cherche", "voudrais", "veux", "randonnee", "jours", "jour", "nuits", "nuit", "semaine", "personnes"
    ]

    private static func freePlaces(in text: String, avoiding known: [LennyRequest.Mention]) -> [LennyRequest.Mention] {
        let knownKeys = known.map { fold($0.name) }
        var found: [String: LennyRequest.Mention] = [:]

        func add(_ name: String, at position: Int) {
            // "Hi Lenny" is not a place: drop the little words at either end.
            var words = name.split(separator: " ").map(String.init)
            while let first = words.first, notPlaces.contains(fold(first)) { words.removeFirst() }
            while let last = words.last, notPlaces.contains(fold(last)) { words.removeLast() }
            let cleaned = words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            let key = fold(cleaned)
            guard key.count >= 3, !notPlaces.contains(key),
                  !knownKeys.contains(where: { $0.contains(key) || key.contains($0) })
            else { return }
            if found[key] == nil {
                found[key] = .init(name: cleaned, kind: .place, pods: [], position: position)
            }
        }

        // 1. Apple's language tagger.
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        if let language = recognizer.dominantLanguage { tagger.setLanguage(language, range: text.startIndex..<text.endIndex) }
        let confirmed = Set<String>()
        _ = confirmed
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            if tag == .placeName {
                add(String(text[range]), at: text.distance(from: text.startIndex, to: range.lowerBound))
            }
            return true
        }

        // 2. Capitalised names ("Lake Braies", "Passo di Giau"), which the
        // tagger misses in short or lower-case-heavy sentences.
        let pattern = #"(?<![\p{L}])[A-ZÀ-ÖØ-Þ][\p{L}'’\-]+(?:\s+(?:(?:de|di|du|des|del|della|von|am|la|le|les|the|d'|l')\s*)?[A-ZÀ-ÖØ-Þ][\p{L}'’\-]+)*"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let whole = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: whole) {
                guard let range = Range(match.range, in: text) else { continue }
                let phrase = String(text[range])
                // A lone capital at the start of a sentence is just grammar.
                let before = text[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let startsSentence = before.isEmpty || before.hasSuffix(".") || before.hasSuffix("!") || before.hasSuffix("?")
                if startsSentence, !phrase.contains(" "), !followsConnector(after: range, in: text) { continue }
                add(phrase, at: match.range.location)
            }
        }

        // A phrase that is part of a longer one is the longer one.
        let keys = found.keys.sorted { $0.count > $1.count }
        var kept: [LennyRequest.Mention] = []
        var keptKeys: [String] = []
        for key in keys {
            if keptKeys.contains(where: { $0.contains(key) }) { continue }
            keptKeys.append(key)
            if let mention = found[key] { kept.append(mention) }
        }
        return kept
    }

    /// "Chamonix to Zermatt": the first word is a place because "to" follows.
    private static func followsConnector(after range: Range<String.Index>, in text: String) -> Bool {
        let after = fold(String(text[range.upperBound...].prefix(14))).trimmingCharacters(in: .whitespaces)
        return ["to ", "a ", "vers ", "->", "→", "then", "puis", "and ", "et ", ","].contains { after.hasPrefix($0) }
    }

    // MARK: - Numbers

    private static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5, "six ": 6, "sept": 7, "huit": 8, "neuf": 9, "dix": 10,
        "a": 1, "an": 1
    ]

    private static let number = #"(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|une?|deux|trois|quatre|cinq|sept|huit|neuf|dix)"#

    private static func value(of token: String) -> Int? {
        Int(token) ?? numberWords[token]
    }

    private static func firstNumber(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return value(of: String(text[range]))
    }

    private static func guests(in folded: String) -> Int? {
        if folded.range(of: #"\b(solo|alone|by myself|on my own|seul|seule|tout seul)\b"#, options: .regularExpression) != nil { return 1 }
        if folded.range(of: #"\b(couple|both of us|nous deux|a deux|the two of us)\b"#, options: .regularExpression) != nil { return 2 }
        let patterns = [
            number + #"\s+(?:people|persons|guests|adults|hikers|travell?ers|friends|of us|personnes|adultes|randonneurs|amis|pers)\b"#,
            #"\b(?:group|family|party|famille|groupe)\s+of\s+"# + number,
            #"\b(?:we are|we're|nous sommes|on est)\s+"# + number + #"\b"#,
            #"\bfor\s+"# + number + #"\b(?!\s*(?:day|night|week|hour|jour|nuit|semaine|km))"#
        ]
        for pattern in patterns {
            if let count = firstNumber(in: folded, pattern: pattern), (1...12).contains(count) { return count }
        }
        return nil
    }

    /// (days, nights) of the stay: "5 days", "4 nights", "a week", "weekend".
    private static func stay(in folded: String) -> (Int?, Int?) {
        let nights = firstNumber(in: folded, pattern: number + #"[\s-]*(?:nights?|nuits?|nacht|naechte|notti)\b"#)
        var days = firstNumber(in: folded, pattern: number + #"[\s-]*(?:days?|jours?|tage|giorni)\b"#)
        if days == nil, let weeks = firstNumber(in: folded, pattern: #"(\d{1,2}|a|an|one|two|three|four|une?|deux|trois|quatre)[\s-]*(?:weeks?|semaines?)\b"#) { days = weeks * 7 }
        if days == nil, folded.range(of: #"\b(?:weekend|week-end)\b"#, options: .regularExpression) != nil { days = 2 }
        return (days.flatMap { (1...60).contains($0) ? $0 : nil }, nights.flatMap { (1...60).contains($0) ? $0 : nil })
    }

    // MARK: - Dates

    /// The first real date in the sentence ("next Friday", "on 12 August"), not
    /// a length of time ("in 5 days").
    private static func startDate(in text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let date = match.date, let range = Range(match.range, in: text) else { continue }
            let phrase = fold(String(text[range]))
            // "in 5 days", "5 days", "in a week" are durations, not dates.
            if phrase.range(of: #"^(?:in\s+|dans\s+)?"# + number + #"\s*(?:days?|weeks?|nights?|months?|jours?|semaines?|nuits?|mois)\b"#, options: .regularExpression) != nil { continue }
            if phrase.range(of: #"^\d+$"#, options: .regularExpression) != nil { continue }
            let day = Calendar.current.startOfDay(for: date)
            if day >= today { return day }
        }
        return nil
    }

    // MARK: - Folding

    /// Lower case, without accents: "Dôme" and "dome" are the same word.
    private static func fold(_ string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}

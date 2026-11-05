import Foundation
import CoreLocation

/// "Alps", "Dolomites", "Scotland": an area, not a place to sleep in. Lenny
/// answers like an itinerary pro: a hut-to-hut chain across it, about a day's
/// walk between stops, each one the best-documented hut around (partner huts
/// first), with a few more nearby to swap in. Built on the device from the
/// huts the app knows; nothing is fetched.
enum LennyAreaRoute {
    /// A named mountain range, which no hut's region says outright.
    private struct Range {
        let names: [String]
        let title: String
        let latitude: Double
        let longitude: Double
        let radiusKm: Double
    }

    private static let ranges: [Range] = [
        Range(names: ["alps", "alpes", "alpen", "alpi", "european alps"], title: "the Alps", latitude: 46.5, longitude: 10.0, radiusKm: 450),
        Range(names: ["dolomites", "dolomiti", "dolomiten"], title: "the Dolomites", latitude: 46.45, longitude: 11.85, radiusKm: 70),
        Range(names: ["pyrenees", "pirineos"], title: "the Pyrenees", latitude: 42.7, longitude: 0.5, radiusKm: 220),
        Range(names: ["mont blanc", "mont-blanc", "massif du mont blanc"], title: "Mont Blanc", latitude: 45.83, longitude: 6.87, radiusKm: 45),
        Range(names: ["tyrol", "tirol", "tirolo"], title: "Tyrol", latitude: 47.1, longitude: 11.2, radiusKm: 110),
        Range(names: ["julian alps", "alpes juliennes", "alpi giulie"], title: "the Julian Alps", latitude: 46.3, longitude: 13.8, radiusKm: 50),
        Range(names: ["tatras", "tatra", "tatry"], title: "the Tatras", latitude: 49.2, longitude: 20.0, radiusKm: 50)
    ]

    /// Too few huts for a route: the usual search takes over.
    private static let minimumPods = 6

    /// How the user asked to shape the route ("make it a loop", "shorter
    /// days", "only huts I can book").
    struct Options: Equatable {
        /// Who is walking: it sets how far a day goes, how much climbing is
        /// fine, and when a day is too long and gets a stop in the middle.
        enum Level: Equatable {
            case beginner, regular, expert

            /// The stage between two stops, in km as the crow flies.
            var ideal: Double { self == .beginner ? 12 : self == .expert ? 28 : 20 }
            /// A day longer than this (hours on the trail) is split by another hut.
            var longestDay: Double { self == .beginner ? 5.5 : self == .expert ? 10.5 : 8 }
            /// Points taken off a hut's score for every 150 m of climb to reach it.
            var climbCost: Double { self == .beginner ? 1.0 : self == .expert ? 0 : 0.3 }
        }

        var loop = false
        var level = Level.regular
        var bookableOnly = false
    }

    /// What the builder made.
    struct Route {
        var stops: [LennySearchViewModel.JourneyStop]
        var isLoop: Bool
    }

    struct Area {
        let name: String
        let pods: [Pod]
    }

    /// The area a request is about, when it's only that: one country, one big
    /// region, or one known range.
    static func area(for request: LennyRequest, pods allPods: [Pod]) -> Area? {
        guard request.mentions.count == 1, let mention = request.mentions.first else { return nil }
        switch mention.kind {
        case .pod:
            return nil
        case .country:
            return mention.pods.count >= minimumPods ? Area(name: mention.name, pods: mention.pods) : nil
        case .region:
            return spread(of: mention.pods) >= 40 && mention.pods.count >= minimumPods ? Area(name: mention.name, pods: mention.pods) : nil
        case .place:
            let folded = LennyText.fold(mention.name).trimmingCharacters(in: .whitespaces)
            guard let range = ranges.first(where: { range in range.names.contains { folded == $0 || folded.hasSuffix(" " + $0) } }) else { return nil }
            let inside = allPods.filter { pod in
                guard let lat = pod.latitude, let lng = pod.longitude else { return false }
                return distance(lat, lng, range.latitude, range.longitude) <= range.radiusKm
            }
            return inside.count >= minimumPods ? Area(name: tr(range.title), pods: inside) : nil
        }
    }

    /// How many stops: about one for every two days of the stay, four when it
    /// isn't said.
    static func stopCount(for request: LennyRequest) -> Int {
        guard let total = request.nights ?? request.days, total > 0 else { return 4 }
        return max(2, min(LennyRequestParser.maxStops, (total + 1) / 2))
    }

    // MARK: - The chain

    private struct Candidate {
        let pod: Pod
        let lat: Double
        let lng: Double
        let score: Double
        let altitude: Int?
    }

    /// The stops across `area`, in walking order. Empty when there's no chain
    /// to make (the usual search then takes over).
    static func stops(in area: Area, count: Int, wants: [String], photoIDs: Set<UUID>, options: Options = Options()) -> Route {
        let none = Route(stops: [], isLoop: false)
        let candidates: [Candidate] = area.pods.compactMap { pod in
            guard let lat = pod.latitude, let lng = pod.longitude,
                  OpeningStatus.evaluate(pod.openingHours)?.isOpen != false,
                  !options.bookableOnly || pod.isBookable
            else { return nil }
            var score = Double(PodQuality.score(pod, hasPhoto: photoIDs.contains(pod.id)))
            if pod.isBookable { score += 4 }
            score += Double(wants.filter { (pod.facilities ?? []).contains($0) }.count) * 2
            return Candidate(pod: pod, lat: lat, lng: lng, score: score, altitude: pod.altitudeM)
        }
        guard candidates.count >= minimumPods else { return none }

        // Start where there is the most to choose from: a good hut with many
        // others a day's walk around it.
        let best = candidates.sorted { $0.score > $1.score }.prefix(60)
        guard let start = best.max(by: { startValue($0, in: candidates) < startValue($1, in: candidates) }) else { return none }

        var chain: [Candidate] = []
        var isLoop = false
        if options.loop, count >= 3, let ring = loop(from: start, count: count, in: candidates, level: options.level) {
            chain = ring
            isLoop = true
        } else {
            chain = oneWay(from: start, count: count, in: candidates, level: options.level)
        }
        guard chain.count >= 2 else { return none }
        // A day that would take too long for this walker gets a hut in the middle.
        let split = splitLongDays(chain, in: candidates, level: options.level, isLoop: isLoop)
        chain = split.chain
        let used = Set(chain.map(\.pod.id))

        var names: Set<String> = []
        var stopNames: [String] = []
        let stops = chain.enumerated().map { index, stop in
            let name = stopName(stop.pod, taken: &names)
            let prior = stopNames.last ?? ""
            stopNames.append(name)
            let alternatives = candidates
                .filter { $0.pod.id != stop.pod.id && !used.contains($0.pod.id) && distance($0.lat, $0.lng, stop.lat, stop.lng) <= 10 }
                .sorted { $0.score > $1.score }
                .prefix(8)
            var distances: [UUID: Double] = [:]
            for alternative in alternatives { distances[alternative.pod.id] = distance(alternative.lat, alternative.lng, stop.lat, stop.lng) }

            let reason: String
            if index == 0 {
                reason = "A good place to start in \(area.name)"
            } else if split.inserted.contains(stop.pod.id) {
                reason = "A stop to break up a long day after \(prior)"
            } else {
                let from = chain[index - 1]
                reason = "About \(Int(distance(from.lat, from.lng, stop.lat, stop.lng).rounded())) km on from \(prior)"
            }
            return LennySearchViewModel.JourneyStop(
                name: name,
                pods: [stop.pod] + alternatives.map(\.pod),
                isResolved: true,
                distancesKm: distances,
                pickReason: LennySearchViewModel.withWants(reason, top: stop.pod, wants: wants),
                isStage: true
            )
        }
        return Route(stops: stops, isLoop: isLoop)
    }

    /// A chain that keeps going, a day's walk at a time.
    private static func oneWay(from start: Candidate, count: Int, in candidates: [Candidate], level: Options.Level) -> [Candidate] {
        var chain = [start]
        var used: Set<UUID> = [start.pod.id]
        var current = start
        var previous: Candidate?
        while chain.count < count, let next = next(after: current, before: previous, in: candidates, used: used, level: level) {
            chain.append(next)
            used.insert(next.pod.id)
            previous = current
            current = next
        }
        return chain
    }

    /// A ring through `count` huts that ends back near where it began: the
    /// circle's length is the stages end to end, it leans toward where the
    /// huts are, and each point on it takes the best hut around.
    private static func loop(from start: Candidate, count: Int, in candidates: [Candidate], level: Options.Level) -> [Candidate]? {
        let stage = level.ideal
        let radius = stage * Double(count) / (2 * .pi)
        let nearby = candidates.filter { distance($0.lat, $0.lng, start.lat, start.lng) <= radius * 3 }
        guard nearby.count >= count else { return nil }
        // km east / north of the start, to turn the circle's middle toward the huts.
        let cosLat = cos(start.lat * .pi / 180)
        let east = nearby.map { ($0.lng - start.lng) * 111.32 * cosLat }.reduce(0, +) / Double(nearby.count)
        let north = nearby.map { ($0.lat - start.lat) * 110.57 }.reduce(0, +) / Double(nearby.count)
        let length = max((east * east + north * north).squareRoot(), 0.001)
        let middle = (x: east / length * radius, y: north / length * radius)
        let first = atan2(-middle.y, -middle.x)   // where the start sits on the circle

        var ring = [start]
        var used: Set<UUID> = [start.pod.id]
        for index in 1..<count {
            let angle = first + 2 * .pi * Double(index) / Double(count)
            let target = (x: middle.x + radius * cos(angle), y: middle.y + radius * sin(angle))
            let pick = candidates
                .filter { !used.contains($0.pod.id) }
                .compactMap { candidate -> (Candidate, Double)? in
                    let dx = (candidate.lng - start.lng) * 111.32 * cosLat - target.x
                    let dy = (candidate.lat - start.lat) * 110.57 - target.y
                    let off = (dx * dx + dy * dy).squareRoot()
                    return off <= max(12, stage * 0.6) ? (candidate, candidate.score - off * 0.3) : nil
                }
                .max { $0.1 < $1.1 }?.0
            guard let pick else { continue }
            ring.append(pick)
            used.insert(pick.pod.id)
        }
        return ring.count >= 3 ? ring : nil
    }

    /// The best hut a day's walk further on, never back toward where we came from.
    private static func next(after current: Candidate, before previous: Candidate?, in candidates: [Candidate], used: Set<UUID>, level: Options.Level) -> Candidate? {
        let stage = level.ideal
        func choose(within window: ClosedRange<Double>) -> Candidate? {
            candidates
                .filter { !used.contains($0.pod.id) }
                .compactMap { candidate -> (Candidate, Double)? in
                    let d = distance(current.lat, current.lng, candidate.lat, candidate.lng)
                    guard window.contains(d) else { return nil }
                    if let previous,
                       distance(previous.lat, previous.lng, candidate.lat, candidate.lng)
                        < distance(previous.lat, previous.lng, current.lat, current.lng) + 5 { return nil }
                    return (candidate, candidate.score - abs(d - stage) * 0.15 - climbCost(from: current, to: candidate, level))
                }
                .max { $0.1 < $1.1 }?.0
        }
        return choose(within: (stage * 0.4)...(stage * 1.6)) ?? choose(within: 5...(stage * 2.4))
    }

    /// What reaching a hut costs a walker in climbing (nothing going down).
    private static func climbCost(from a: Candidate, to b: Candidate, _ level: Options.Level) -> Double {
        guard let up = a.altitude.flatMap({ from in b.altitude.map { $0 - from } }), up > 0 else { return 0 }
        return Double(up) / 150 * level.climbCost
    }

    /// About how long the walk between two huts takes: the crow's flight
    /// stretched for the bends at 4 km/h, plus an hour per 600 m up.
    private static func hours(_ a: Candidate, _ b: Candidate) -> Double {
        let km = distance(a.lat, a.lng, b.lat, b.lng) * 1.3
        let up = a.altitude.flatMap { from in b.altitude.map { max($0 - from, 0) } } ?? 0
        return km / 4 + Double(up) / 600
    }

    /// Puts a hut between two huts whose day is too long for the walker (and
    /// on the way, not off to the side), until every day fits or there are
    /// eight stops. Also the way back of a loop.
    private static func splitLongDays(_ chain: [Candidate], in candidates: [Candidate], level: Options.Level, isLoop: Bool) -> (chain: [Candidate], inserted: Set<UUID>) {
        var chain = chain
        var inserted: Set<UUID> = []
        var index = 0
        var rounds = 0
        while rounds < 24, chain.count < LennyRequestParser.maxStops {
            rounds += 1
            let last = isLoop ? chain.count - 1 : chain.count - 2
            guard index <= last else { break }
            let from = chain[index], to = chain[(index + 1) % chain.count]
            let day = hours(from, to)
            if day > level.longestDay, let middle = between(from, to, in: candidates, excluding: Set(chain.map(\.pod.id))) {
                chain.insert(middle, at: index + 1)
                inserted.insert(middle.pod.id)
                continue   // the first half may still be too long
            }
            index += 1
        }
        return (chain, inserted)
    }

    /// The best hut on the way between two: not a detour, and each half
    /// shorter than the whole, the halves about equal.
    private static func between(_ a: Candidate, _ b: Candidate, in candidates: [Candidate], excluding used: Set<UUID>) -> Candidate? {
        let whole = distance(a.lat, a.lng, b.lat, b.lng)
        let day = hours(a, b)
        return candidates
            .filter { !used.contains($0.pod.id) }
            .compactMap { candidate -> (Candidate, Double)? in
                let first = distance(a.lat, a.lng, candidate.lat, candidate.lng)
                let second = distance(candidate.lat, candidate.lng, b.lat, b.lng)
                guard first + second <= whole * 1.35,
                      hours(a, candidate) < day, hours(candidate, b) < day
                else { return nil }
                return (candidate, candidate.score - abs(first - second) * 0.2)
            }
            .max { $0.1 < $1.1 }?.0
    }

    private static func startValue(_ candidate: Candidate, in candidates: [Candidate]) -> Double {
        let around = candidates.filter { distance($0.lat, $0.lng, candidate.lat, candidate.lng) <= 25 }.count
        return candidate.score + Double(min(around, 12)) * 0.5
    }

    /// The hut's region, or its short name when another stop has that region.
    private static func stopName(_ pod: Pod, taken: inout Set<String>) -> String {
        if let region = pod.region, !region.isEmpty, !taken.contains(region) {
            taken.insert(region)
            return region
        }
        let words = pod.name.split(separator: " ").map(String.init)
        let short = words.count >= 2 && ["rifugio", "refuge", "chalet", "cabane", "hut", "capanna"].contains(LennyText.fold(words[0]))
            ? words.dropFirst().joined(separator: " ") : pod.name
        taken.insert(short)
        return short
    }

    // MARK: - Distances

    /// Kilometres between two points, flat-earth: plenty for a few hundred km.
    static func distance(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let dy = (lat2 - lat1) * 110.57
        let dx = (lng2 - lng1) * 111.32 * cos((lat1 + lat2) / 2 * .pi / 180)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// The widest the pods spread, in km (the corners of their bounding box).
    private static func spread(of pods: [Pod]) -> Double {
        let points = pods.compactMap { pod in pod.latitude.flatMap { lat in pod.longitude.map { (lat, $0) } } }
        guard let first = points.first else { return 0 }
        var minLat = first.0, maxLat = first.0, minLng = first.1, maxLng = first.1
        for (lat, lng) in points {
            minLat = min(minLat, lat); maxLat = max(maxLat, lat)
            minLng = min(minLng, lng); maxLng = max(maxLng, lng)
        }
        return distance(minLat, minLng, maxLat, maxLng)
    }
}

import Foundation

/// One shelf on Home: a title and its pods, laid out in one of three ways so
/// the page has a rhythm. The shelves under "Available tonight" are there to
/// find a pod without typing anything: the highest, the busiest region and the
/// big ones for groups (a kind only fills in when one of those is missing).
struct HomeSection: Identifiable {
    enum Layout {
        /// The big portrait cards in a carousel (`HomePodCard`).
        case hero
        /// Tall cards with the altitude on the photo (`HomeTallCard`).
        case tall
        /// One lead photo and one or two small ones (`HomeMosaic`): needs two pods.
        case mosaic
    }

    let id: String
    let title: String
    let pods: [Pod]
    var layout: Layout = .hero
    /// Everything behind the shelf, for "See all" (the shelf itself shows a few);
    /// nil when the shelf already is everything.
    var allPods: [Pod]?
    /// How "See all" starts out sorted.
    var seeAllSort: HomeAllPodsSheet.Sort = .best
    /// The quiet line under each pod's name in a hero shelf; the default is
    /// "region · beds".
    var subtitle: ((Pod) -> String)?

    /// How many shelves the discovery gives, besides Hand-picked.
    static let maxShelves = 3

    /// The shelves below "Available tonight", in order, alternating shapes so
    /// two alike are never side by side. Each needs enough pods to be worth a
    /// shelf, and a pod can be on several.
    static func discovery(from pods: [Pod]) -> [HomeSection] {
        var tall: [HomeSection] = []
        var mosaics: [HomeSection] = []
        var heroes: [HomeSection] = []

        // A hut above 6,000 m is a typo, not a hut.
        let highest = pods.filter { (1...6_000).contains($0.altitudeM ?? 0) }
            .sorted { ($0.altitudeM ?? 0) > ($1.altitudeM ?? 0) }
        if highest.count >= 3 {
            tall.append(HomeSection(id: "highest", title: "Highest", pods: Array(highest.prefix(8)), layout: .tall, allPods: highest, seeAllSort: .highest))
        }

        let big = pods.filter { ($0.bedsTotal ?? 0) >= 12 }
            .sorted { ($0.bedsTotal ?? 0) > ($1.bedsTotal ?? 0) }
        if big.count >= 2 {
            heroes.append(HomeSection(id: "groups", title: "Room for groups", pods: Array(big.prefix(8)), allPods: big, seeAllSort: .beds) { pod in
                [pod.bedsTotal.map { "\($0) beds" }, pod.region ?? pod.country].compactMap { $0 }.joined(separator: " · ")
            })
        }

        // The busiest region, as a mosaic.
        let regions = Dictionary(grouping: pods.filter { !($0.region ?? "").isEmpty }, by: { $0.region ?? "" })
            .filter { $0.value.count >= 2 }
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
            .prefix(1)
        for (region, group) in regions {
            let ordered = group.sorted { ($0.bedsTotal ?? 0) > ($1.bedsTotal ?? 0) }
            let section = HomeSection(id: "region-\(region)", title: "In \(region)", pods: ordered, layout: .mosaic, allPods: ordered)
            mosaics.append(section)
        }

        // The two most common kinds of pod ("Refuges", "Cabins").
        let kinds = Dictionary(grouping: pods.filter { !$0.podType.isEmpty }, by: { $0.podType.lowercased() })
            .filter { $0.value.count >= 3 }
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
            .prefix(2)
        for (kind, group) in kinds {
            heroes.append(HomeSection(id: "kind-\(kind)", title: plural(kind.capitalized), pods: Array(group.prefix(12)), allPods: group))
        }

        // Tall, mosaic, hero: three shelves at most, so Home stays short.
        var ordered = tall
        var nextMosaic = 0
        var nextHero = 0
        var wantsMosaic = true
        while ordered.count < maxShelves, nextMosaic < mosaics.count || nextHero < heroes.count {
            if wantsMosaic, nextMosaic < mosaics.count {
                ordered.append(mosaics[nextMosaic]); nextMosaic += 1
            } else if nextHero < heroes.count {
                ordered.append(heroes[nextHero]); nextHero += 1
            } else if nextMosaic < mosaics.count {
                ordered.append(mosaics[nextMosaic]); nextMosaic += 1
            }
            wantsMosaic.toggle()
        }
        return ordered
    }

    private static func plural(_ word: String) -> String {
        word.hasSuffix("s") ? word : word + "s"
    }
}

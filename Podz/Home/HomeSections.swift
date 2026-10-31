import Foundation

/// One shelf on Home: a title and its pods, laid out in one of three ways so
/// the page has a rhythm. The shelves under "Available tonight" are there to
/// find a pod without typing anything: the highest, the big ones for groups,
/// each region, each kind.
struct HomeSection: Identifiable {
    enum Layout {
        /// The big portrait cards in a carousel (`HomePodCard`).
        case hero
        /// Tall cards with the altitude on the photo (`HomeTallCard`).
        case tall
        /// One lead photo and two small ones (`HomeMosaic`): needs three pods.
        case mosaic
    }

    let id: String
    let title: String
    let pods: [Pod]
    var layout: Layout = .hero
    /// The quiet line under each pod's name in a hero shelf; the default is
    /// "region · beds".
    var subtitle: ((Pod) -> String)?

    /// The shelves below "Available tonight", in order, alternating shapes so
    /// two alike are never side by side. Each needs enough pods to be worth a
    /// shelf, and a pod can be on several.
    static func discovery(from pods: [Pod]) -> [HomeSection] {
        var tall: [HomeSection] = []
        var mosaics: [HomeSection] = []
        var heroes: [HomeSection] = []

        let highest = pods.filter { ($0.altitudeM ?? 0) > 0 }
            .sorted { ($0.altitudeM ?? 0) > ($1.altitudeM ?? 0) }
        if highest.count >= 3 {
            tall.append(HomeSection(id: "highest", title: "Highest", pods: Array(highest.prefix(8)), layout: .tall))
        }

        let big = pods.filter { ($0.bedsTotal ?? 0) >= 12 }
            .sorted { ($0.bedsTotal ?? 0) > ($1.bedsTotal ?? 0) }
        if big.count >= 2 {
            heroes.append(HomeSection(id: "groups", title: "Room for groups", pods: Array(big.prefix(8))) { pod in
                [pod.bedsTotal.map { "\($0) beds" }, pod.region ?? pod.country].compactMap { $0 }.joined(separator: " · ")
            })
        }

        // The three busiest regions: a mosaic when there are three pods to
        // make one, a carousel otherwise.
        let regions = Dictionary(grouping: pods.filter { !($0.region ?? "").isEmpty }, by: { $0.region ?? "" })
            .filter { $0.value.count >= 2 }
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
            .prefix(3)
        for (region, group) in regions {
            let ordered = group.sorted { ($0.bedsTotal ?? 0) > ($1.bedsTotal ?? 0) }
            let section = HomeSection(id: "region-\(region)", title: "In \(region)", pods: ordered, layout: ordered.count >= 3 ? .mosaic : .hero)
            if section.layout == .mosaic { mosaics.append(section) } else { heroes.append(section) }
        }

        // The two most common kinds of pod ("Refuges", "Cabins").
        let kinds = Dictionary(grouping: pods.filter { !$0.podType.isEmpty }, by: { $0.podType.lowercased() })
            .filter { $0.value.count >= 3 }
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
            .prefix(2)
        for (kind, group) in kinds {
            heroes.append(HomeSection(id: "kind-\(kind)", title: plural(kind.capitalized), pods: group))
        }

        // Tall, mosaic, hero, mosaic, hero, mosaic...
        var ordered = tall
        var nextMosaic = 0
        var nextHero = 0
        var wantsMosaic = true
        while ordered.count < 6, nextMosaic < mosaics.count || nextHero < heroes.count {
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

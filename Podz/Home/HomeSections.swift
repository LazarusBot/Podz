import Foundation

/// One shelf on Home: a title and a row of pod cards. The shelves under
/// "Available tonight" are there to find a pod without typing anything: what
/// you liked, the highest, the big ones for groups, each region, each kind.
struct HomeSection: Identifiable {
    let id: String
    let title: String
    let pods: [Pod]
    /// The quiet line under each pod's name in this shelf; the default is
    /// "region · beds".
    var subtitle: ((Pod) -> String)?

    /// The shelves below "Available tonight", in order. Each one needs enough
    /// pods to be worth a shelf, and a pod can be on several.
    static func discovery(from pods: [Pod], liked: [Pod]) -> [HomeSection] {
        var sections: [HomeSection] = []

        if !liked.isEmpty {
            sections.append(HomeSection(id: "likes", title: "Your likes", pods: liked))
        }

        let highest = pods.filter { ($0.altitudeM ?? 0) > 0 }
            .sorted { ($0.altitudeM ?? 0) > ($1.altitudeM ?? 0) }
        if highest.count >= 3 {
            sections.append(HomeSection(id: "highest", title: "Highest", pods: Array(highest.prefix(8))) { pod in
                [pod.altitudeM.map { "\($0) m" }, pod.region ?? pod.country].compactMap { $0 }.joined(separator: " · ")
            })
        }

        let big = pods.filter { ($0.bedsTotal ?? 0) >= 12 }
            .sorted { ($0.bedsTotal ?? 0) > ($1.bedsTotal ?? 0) }
        if big.count >= 2 {
            sections.append(HomeSection(id: "groups", title: "Room for groups", pods: Array(big.prefix(8))) { pod in
                [pod.bedsTotal.map { "\($0) beds" }, pod.region ?? pod.country].compactMap { $0 }.joined(separator: " · ")
            })
        }

        // The three busiest regions.
        let regions = Dictionary(grouping: pods.filter { !($0.region ?? "").isEmpty }, by: { $0.region ?? "" })
            .filter { $0.value.count >= 2 }
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
            .prefix(3)
        for (region, group) in regions {
            sections.append(HomeSection(id: "region-\(region)", title: "In \(region)", pods: group))
        }

        // The two most common kinds of pod ("Refuges", "Cabins").
        let kinds = Dictionary(grouping: pods.filter { !$0.podType.isEmpty }, by: { $0.podType.lowercased() })
            .filter { $0.value.count >= 3 }
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
            .prefix(2)
        for (kind, group) in kinds {
            sections.append(HomeSection(id: "kind-\(kind)", title: plural(kind.capitalized), pods: group))
        }

        return Array(sections.prefix(6))
    }

    private static func plural(_ word: String) -> String {
        word.hasSuffix("s") ? word : word + "s"
    }
}

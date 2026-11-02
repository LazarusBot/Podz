import Foundation

/// How well documented a hut is, so Home can lead with the ones a traveler can
/// actually use (a photo, a way to reach them, facts) instead of a bare name on
/// a map. A hand-picked hut (`featured`) always leads.
enum PodQuality {
    /// 0 to 10, plus 5 for a hand-picked hut.
    static func score(_ pod: Pod, hasPhoto: Bool) -> Int {
        var score = 0
        if hasPhoto { score += 3 }
        if pod.hasContact { score += 2 }
        if pod.altitudeM != nil { score += 1 }
        if pod.bedsTotal != nil { score += 1 }
        if !(pod.facilities ?? []).isEmpty { score += 1 }
        if hutClean(pod.description) != nil { score += 1 }
        if hutClean(pod.openingHours) != nil || pod.priceText != nil { score += 1 }
        if pod.featured == true { score += 5 }
        return score
    }

    /// Worth a place on a Home shelf: a photo and a way to reach it, or hand-picked.
    static func isShelfWorthy(_ pod: Pod, hasPhoto: Bool) -> Bool {
        pod.featured == true || score(pod, hasPhoto: hasPhoto) >= 5
    }

    /// Best documented first; partners before listed huts; then by name.
    static func ranked(_ pods: [Pod], photoIDs: Set<UUID>) -> [Pod] {
        pods.sorted { a, b in
            if a.isBookable != b.isBookable { return a.isBookable }
            let sa = score(a, hasPhoto: photoIDs.contains(a.id))
            let sb = score(b, hasPhoto: photoIDs.contains(b.id))
            if sa != sb { return sa > sb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}

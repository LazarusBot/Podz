//
//  LennySearchViewModel.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LennySearchViewModel: ObservableObject {
    static let shared = LennySearchViewModel()
    
    enum Phase: Equatable {
        case idle       // not searching
        case searching  // step-by-step progress
        case results    // matching pods found
    }
    
    struct StepInfo: Identifiable {
        let id: Int
        var title: String
        var subtitle: String
        var isDone: Bool
    }
    
    /// One stop of the itinerary and the pods found around it, resolved one
    /// stop at a time.
    struct JourneyStop: Identifiable {
        let id = UUID()
        var name: String
        /// Best first: Lenny's pick leads.
        var pods: [Pod]
        var isResolved: Bool
        /// How far each pod is from the stop, when it's known.
        var distancesKm: [UUID: Double] = [:]
        /// Why the first pod leads ("Closest to Lake Braies").
        var pickReason: String?
        /// A stage of a walking route across an area: the picks are a day's walk apart.
        var isStage = false

        /// "3.2 km" / "Under 1 km", when the pod's distance is known.
        func distanceText(for pod: Pod) -> String? {
            guard let km = distancesKm[pod.id] else { return nil }
            return km < 1 ? "Under 1 km" : km < 10 ? String(format: "%.1f km", km) : "\(Int(km.rounded())) km"
        }

        /// "3 km from Lake Braies" for any pod whose distance is known.
        func distanceCaption(for pod: Pod) -> String? {
            distanceText(for: pod).map { "\($0) from \(name)" }
        }
    }
    
    @Published var phase: Phase = .idle
    @Published var itineraryText = ""
    @Published var steps: [StepInfo] = []
    @Published var journeyStops: [JourneyStop] = []
    @Published var errorMessage: String?
    /// What Lenny understood from the sentence (places, guests, dates, stay).
    @Published var request: LennyRequest?
    private var searchTask: Task<Void, Never>?
    /// The area a route was made across (Alps, Scotland), to reshape it.
    private var area: LennyAreaRoute.Area?
    private var areaStopCount = 4
    @Published private(set) var routeOptions = LennyAreaRoute.Options()
    @Published private(set) var routeIsLoop = false
    /// Lenny's line after reshaping the route, and whether it didn't work.
    @Published private(set) var refineNote: String?
    @Published private(set) var refineFailed = false

    /// What the plan is called when saved: "Across the Alps", or the places in order.
    var planTitle: String? {
        if let area { return tr("Across \(area.name)") }
        let names = request?.mentions.map(\.name) ?? []
        return names.isEmpty ? nil : names.joined(separator: " → ")
    }

    /// A route across an area can be reshaped (loop, shorter days, bookable huts only).
    var canRefine: Bool { area != nil && !journeyStops.isEmpty }

    /// Leaves the search: stops whatever is still running and clears it all.
    func forceReset() {
        searchTask?.cancel()
        phase = .idle
        itineraryText = ""
        steps = []
        journeyStops = []
        request = nil
        errorMessage = nil
        resetRoute()
    }

    private func resetRoute() {
        area = nil
        routeOptions = LennyAreaRoute.Options()
        routeIsLoop = false
        refineNote = nil
        refineFailed = false
    }

    /// Reshapes the route across the area: `change` edits the options; Lenny
    /// says `done`, or `failed` when no route fits (the route then stays as it was).
    func refine(done: String, failed: String, _ change: (inout LennyAreaRoute.Options) -> Void) {
        guard let area else { return }
        var options = routeOptions
        change(&options)
        let route = LennyAreaRoute.stops(
            in: area, count: areaStopCount, wants: request?.facilities ?? [],
            photoIDs: Self.photoIDs, options: options
        )
        if route.stops.isEmpty || (options.loop && !route.isLoop) {
            refineNote = failed
            refineFailed = true
            return
        }
        routeOptions = options
        routeIsLoop = route.isLoop
        journeyStops = route.stops
        refineNote = done
        refineFailed = false
    }

    private static var photoIDs: Set<UUID> {
        Set(PodsStore.shared.primaryPhotoByPodId.filter { !$0.value.isEmpty }.keys)
    }
    
    /// Starts a search for `text` in a task the view model owns, so leaving
    /// the screen (`forceReset`) also stops the steps still ticking.
    func start(_ text: String) {
        searchTask?.cancel()
        itineraryText = text
        // A fresh start (also a retry after an error): nothing left over.
        errorMessage = nil
        journeyStops = []
        request = nil
        resetRoute()
        // The steps are on screen from the first frame, all still to do.
        steps = Self.initialSteps()
        phase = .searching
        searchTask = Task { await submit() }
    }

    /// The three steps every search walks through, so the screen's layout
    /// never changes shape while it waits.
    private static func initialSteps() -> [StepInfo] {
        [
            StepInfo(id: 0, title: "Extracting your stops.", subtitle: "", isDone: false),
            StepInfo(id: 1, title: "Finding the best huts around here.", subtitle: "", isDone: false),
            StepInfo(id: 2, title: "Loading your itinerary.", subtitle: "", isDone: false)
        ]
    }

    func submit() async {
        guard !itineraryText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let input = itineraryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let allPods = PodsStore.shared.pods

        // Nothing loaded to search in (offline, or still starting up).
        if allPods.isEmpty {
            phase = .searching
            steps = Self.initialSteps()
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            errorMessage = "I can't see any huts right now. Check your connection and try again."
            phase = .results
            return
        }

        phase = .searching
        errorMessage = nil
        steps = Self.initialSteps()

        // 1 - Understand the sentence, however long: places, and the number
        // of guests, the dates and the stay when they're in it.
        let request = LennyRequestParser.parse(input, pods: allPods)
        self.request = request
        try? await Task.sleep(nanoseconds: 450_000_000) // a beat, so the step reads
        guard !Task.isCancelled else { return }
        guard !request.mentions.isEmpty else {
            errorMessage = request.facilities.isEmpty
                ? "I couldn't make out a place in that. Try a town, a lake or a peak."
                : "Tell me where you're heading and I'll look for huts with \(LennyFacilities.phrase(request.facilities))."
            Analytics.shared.track(.lennySearch, ["found": "no_place"])
            phase = .results
            return
        }
        steps[0].title = "Extracting \(Self.stopCount(request.mentions.count))."
        steps[0].subtitle = request.mentions.map(\.name).joined(separator: ", ") + (request.understood.map { "  ·  \($0)" } ?? "")
        steps[0].isDone = true

        // An area on its own ("Alps", "Scotland"): Lenny plans a route across
        // it, a day's walk between huts, instead of one stop.
        var areaStops: [JourneyStop] = []
        var areaName: String?
        if let found = LennyAreaRoute.area(for: request, pods: allPods) {
            let count = LennyAreaRoute.stopCount(for: request)
            var options = LennyAreaRoute.Options()
            options.level = request.level ?? .regular
            areaStops = LennyAreaRoute.stops(in: found, count: count, wants: request.facilities, photoIDs: Self.photoIDs, options: options).stops
            areaName = found.name
            if !areaStops.isEmpty {
                area = found
                areaStopCount = count
                routeOptions.level = request.level ?? .regular
            }
        }

        if let areaName, !areaStops.isEmpty {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            steps[0].title = "Planning \(Self.stopCount(areaStops.count)) across \(areaName)."
            steps[1].subtitle = "A day's walk apart"
            steps[1].isDone = true
            journeyStops = areaStops
        } else {
            // 2 - Place every stop at once (pods and regions already know where
            // they are; the rest are geocoded side by side).
            async let located = Self.locate(request.mentions)
            try? await Task.sleep(nanoseconds: 450_000_000)
            let stops = await located
            guard !Task.isCancelled else { return }
            steps[1].subtitle = "Around each stop"
            steps[1].isDone = true

            // 3 - Pods around each stop, nearest first, and some along the way.
            journeyStops = Self.journey(from: stops, pods: allPods, wants: request.facilities)
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        let nothing = journeyStops.allSatisfy { $0.pods.isEmpty }
        steps[2].subtitle = nothing ? "Nothing found" : "Your plan is ready"
        steps[2].isDone = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }

        if nothing {
            errorMessage = "I couldn't find any huts along that route. Try another stop, or a wider area."
        }
        Analytics.shared.track(.lennySearch, [
            "stops": "\(journeyStops.count)",
            "pods": "\(journeyStops.reduce(0) { $0 + $1.pods.count })",
            "found": nothing ? "no" : "yes"
        ])
        phase = .results
    }

    // MARK: - Finding the pods

    private struct Located {
        let mention: LennyRequest.Mention
        let coordinate: CLLocationCoordinate2D?
    }

    /// Where each mention is: known pods give their own middle, the rest are
    /// geocoded, all at the same time.
    private nonisolated static func locate(_ mentions: [LennyRequest.Mention]) async -> [Located] {
        await withTaskGroup(of: (Int, CLLocationCoordinate2D?).self) { group in
            for (index, mention) in mentions.enumerated() {
                group.addTask {
                    if let middle = Self.middle(of: mention.pods) { return (index, middle) }
                    return (index, await LennyItineraryParser.geocode(mention.name)?.coordinate)
                }
            }
            var coordinates: [Int: CLLocationCoordinate2D] = [:]
            for await (index, coordinate) in group {
                if let coordinate { coordinates[index] = coordinate }
            }
            return mentions.enumerated().map { Located(mention: $0.element, coordinate: coordinates[$0.offset]) }
        }
    }

    private nonisolated static func middle(of pods: [Pod]) -> CLLocationCoordinate2D? {
        let located = pods.compactMap { pod -> (Double, Double)? in
            guard let lat = pod.latitude, let lng = pod.longitude else { return nil }
            return (lat, lng)
        }
        guard !located.isEmpty else { return nil }
        return CLLocationCoordinate2D(
            latitude: located.map(\.0).reduce(0, +) / Double(located.count),
            longitude: located.map(\.1).reduce(0, +) / Double(located.count)
        )
    }

    private static func km(_ pod: Pod, from point: CLLocationCoordinate2D) -> Double? {
        guard let lat = pod.latitude, let lng = pod.longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lng)
            .distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude)) / 1000
    }

    /// Pods within the first radius that has any (50, then 100, then 160 km),
    /// nearest first.
    private static func nearest(to point: CLLocationCoordinate2D, in pods: [Pod], radii: [Double] = [50, 100, 160]) -> (pods: [Pod], distances: [UUID: Double]) {
        let measured = pods.compactMap { pod in km(pod, from: point).map { (pod, $0) } }
        for radius in radii {
            let within = measured.filter { $0.1 <= radius }.sorted { $0.1 < $1.1 }
            if !within.isEmpty {
                return (within.map(\.0), Dictionary(uniqueKeysWithValues: within.map { ($0.0.id, $0.1) }))
            }
        }
        return ([], [:])
    }

    private static func journey(from located: [Located], pods allPods: [Pod], wants: [String] = []) -> [JourneyStop] {
        var stops: [(stop: JourneyStop, coordinate: CLLocationCoordinate2D?)] = []

        for item in located {
            let name = item.mention.name
            switch item.mention.kind {
            case .pod:
                // The pod asked for, then its neighbours.
                guard let pod = item.mention.pods.first else { continue }
                var ordered = [pod]
                var distances: [UUID: Double] = [pod.id: 0]
                if let point = item.coordinate {
                    let around = nearest(to: point, in: allPods.filter { $0.id != pod.id }, radii: [40])
                    ordered += around.pods
                    distances.merge(around.distances) { first, _ in first }
                }
                // The pod asked for stays first; its neighbours lead with what was asked.
                ordered = [pod] + ranked(Array(ordered.dropFirst()), wants: wants)
                stops.append((JourneyStop(name: name, pods: ordered, isResolved: true, distancesKm: distances, pickReason: "You asked for it"), item.coordinate))
            case .region, .country:
                // No point to measure from: the pick is the pod with the most beds.
                let byBeds = ranked(item.mention.pods.sorted { ($0.bedsTotal ?? 0) > ($1.bedsTotal ?? 0) }, wants: wants)
                let reason = withWants(byBeds.first?.bedsTotal.map { "Most beds in \(name), \($0)" }, top: byBeds.first, wants: wants)
                stops.append((JourneyStop(name: name, pods: byBeds, isResolved: true, pickReason: reason), item.coordinate))
            case .place:
                guard let point = item.coordinate else {
                    stops.append((JourneyStop(name: name, pods: [], isResolved: true), nil))
                    continue
                }
                let around = nearest(to: point, in: allPods)
                let pods = ranked(around.pods, wants: wants)
                stops.append((JourneyStop(
                    name: name, pods: pods, isResolved: true,
                    distancesKm: around.distances,
                    pickReason: pods.isEmpty ? nil : withWants("Closest to \(name)", top: pods.first, wants: wants)
                ), point))
            }
        }

        // A long leg ("Chamonix to Zermatt") has pods in the middle too.
        var withWaypoints: [JourneyStop] = []
        for (index, item) in stops.enumerated() {
            withWaypoints.append(item.stop)
            guard index + 1 < stops.count, withWaypoints.count < 8,
                  let from = item.coordinate, let to = stops[index + 1].coordinate
            else { continue }
            let legKm = CLLocation(latitude: from.latitude, longitude: from.longitude)
                .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude)) / 1000
            guard legKm > 90 else { continue }
            let middle = CLLocationCoordinate2D(latitude: (from.latitude + to.latitude) / 2, longitude: (from.longitude + to.longitude) / 2)
            let already = Set(item.stop.pods.map(\.id)).union(stops[index + 1].stop.pods.map(\.id))
            let around = nearest(to: middle, in: allPods.filter { !already.contains($0.id) }, radii: [40])
            guard !around.pods.isEmpty else { continue }
            withWaypoints.append(JourneyStop(
                name: "Between \(item.stop.name) and \(stops[index + 1].stop.name)",
                pods: around.pods, isResolved: true,
                distancesKm: around.distances,
                pickReason: "Closest to the middle of your route"
            ))
        }
        return withWaypoints
    }

    // MARK: - Facilities asked for

    /// Huts that have everything asked for first, then those with some of it,
    /// each group keeping its order (nearest, or most beds). Nothing is left
    /// out: the data is incomplete, and a hut that lists nothing may still
    /// have it.
    static func ranked(_ pods: [Pod], wants: [String]) -> [Pod] {
        guard !wants.isEmpty else { return pods }
        func score(_ pod: Pod) -> Int { wants.filter { (pod.facilities ?? []).contains($0) }.count }
        return pods.enumerated()
            .sorted { (score($0.element), -$0.offset) > (score($1.element), -$1.offset) }
            .map(\.element)
    }

    /// Lenny's pick reason, saying what the pick has of what was asked, or that
    /// no hut lists it.
    static func withWants(_ reason: String?, top: Pod?, wants: [String]) -> String? {
        guard let reason, !wants.isEmpty, let top else { return reason }
        let has = wants.filter { (top.facilities ?? []).contains($0) }
        if has.isEmpty { return "\(reason). None lists \(LennyFacilities.phrase(wants))" }
        return "\(reason), with \(LennyFacilities.phrase(has))"
    }

    /// "one stop", "three stops", "12 stops" — the step title's wording.
    private static func stopCount(_ count: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        let number = count < words.count ? words[count] : "\(count)"
        return "\(number) \(count == 1 ? "stop" : "stops")"
    }
}

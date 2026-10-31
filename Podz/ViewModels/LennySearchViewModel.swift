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
        case idle       // just the chip, not active
        case editing    // full-width text field, typing itinerary
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
    @Published var isKeyboardFocused = false
    private var dismissTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    
    func activate() {
        phase = .editing
        isKeyboardFocused = true
    }
    
    func cancel() {
        dismissTask?.cancel()
        isKeyboardFocused = false
        dismissTask = Task {
            // Let the keyboard's own dismiss animation finish before the
            // tab bar reappears — otherwise the two run out of sync and
            // the bar briefly floats above the still-closing keyboard.
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            phase = .idle
            itineraryText = ""
            steps = []
            journeyStops = []
            errorMessage = nil
        }
    }
    
    /// Switches the still-focused search bar back to plain location
    /// search. Unlike `cancel()`, the bar itself never goes away here —
    /// HomeSearchRow just swaps its icon/placeholder/chip back — so
    /// there's no keyboard-dismiss animation to wait out.
    func revertToLocationSearch() {
        dismissTask?.cancel()
        phase = .idle
        itineraryText = ""
        errorMessage = nil
    }

    /// Immediate reset, no animation delay — used as a safety net (e.g.
    /// recovering from an app-background/foreground edge case), unlike
    /// `cancel()` which deliberately waits for the keyboard to finish
    /// dismissing before clearing state.
    func forceReset() {
        dismissTask?.cancel()
        searchTask?.cancel()
        isKeyboardFocused = false
        phase = .idle
        itineraryText = ""
        steps = []
        journeyStops = []
        errorMessage = nil
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
            StepInfo(id: 1, title: "Finding the best pods around here.", subtitle: "", isDone: false),
            StepInfo(id: 2, title: "Loading your itinerary.", subtitle: "", isDone: false)
        ]
    }

    func submit() async {
        guard !itineraryText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        dismissTask?.cancel()
        let input = itineraryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let allPods = PodsStore.shared.pods

        // Nothing loaded to search in (offline, or still starting up).
        if allPods.isEmpty {
            phase = .searching
            steps = Self.initialSteps()
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            errorMessage = "I can't see any pods right now. Check your connection and try again."
            phase = .results
            return
        }

        isKeyboardFocused = false
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
            errorMessage = "I couldn't make out a place in that. Try a town, a lake or a peak."
            phase = .results
            return
        }
        steps[0].title = "Extracting \(Self.stopCount(request.mentions.count))."
        steps[0].subtitle = request.mentions.map(\.name).joined(separator: ", ") + (request.understood.map { "  ·  \($0)" } ?? "")
        steps[0].isDone = true

        // 2 - Place every stop at once (pods and regions already know where
        // they are; the rest are geocoded side by side).
        async let located = Self.locate(request.mentions)
        try? await Task.sleep(nanoseconds: 450_000_000)
        let stops = await located
        guard !Task.isCancelled else { return }
        steps[1].subtitle = "Around each stop"
        steps[1].isDone = true

        // 3 - Pods around each stop, nearest first, and some along the way.
        journeyStops = Self.journey(from: stops, pods: allPods)
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        let nothing = journeyStops.allSatisfy { $0.pods.isEmpty }
        steps[2].subtitle = nothing ? "Nothing found" : "Your plan is ready"
        steps[2].isDone = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }

        if nothing {
            errorMessage = "I couldn't find any pods along that route. Try another stop, or a wider area."
        }
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

    private static func journey(from located: [Located], pods allPods: [Pod]) -> [JourneyStop] {
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
                stops.append((JourneyStop(name: name, pods: ordered, isResolved: true, distancesKm: distances, pickReason: "You asked for it"), item.coordinate))
            case .region, .country:
                // No point to measure from: the pick is the pod with the most beds.
                let byBeds = item.mention.pods.sorted { ($0.bedsTotal ?? 0) > ($1.bedsTotal ?? 0) }
                let reason = byBeds.first?.bedsTotal.map { "Most beds in \(name), \($0)" }
                stops.append((JourneyStop(name: name, pods: byBeds, isResolved: true, pickReason: reason), item.coordinate))
            case .place:
                guard let point = item.coordinate else {
                    stops.append((JourneyStop(name: name, pods: [], isResolved: true), nil))
                    continue
                }
                let around = nearest(to: point, in: allPods)
                stops.append((JourneyStop(
                    name: name, pods: around.pods, isResolved: true,
                    distancesKm: around.distances,
                    pickReason: around.pods.isEmpty ? nil : "Closest to \(name)"
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

    /// "one stop", "three stops", "12 stops" — the step title's wording.
    private static func stopCount(_ count: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        let number = count < words.count ? words[count] : "\(count)"
        return "\(number) \(count == 1 ? "stop" : "stops")"
    }
}

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

        /// "3 km from Lake Braies" for any pod whose distance is known.
        func distanceCaption(for pod: Pod) -> String? {
            guard let km = distancesKm[pod.id] else { return nil }
            let amount = km < 1 ? "Under 1 km" : km < 10 ? String(format: "%.1f km", km) : "\(Int(km.rounded())) km"
            return "\(amount) from \(name)"
        }
    }
    
    @Published var phase: Phase = .idle
    @Published var itineraryText = ""
    @Published var steps: [StepInfo] = []
    @Published var journeyStops: [JourneyStop] = []
    @Published var errorMessage: String?
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
        let trimmedInput = itineraryText.trimmingCharacters(in: .whitespaces)
        
        // Fast path: the input is literally a country we already have
        // pods for ("Slovenia", "France"...) — skip NLP/geocoding
        // entirely, this is both faster and far more reliable than
        // running it through place-name extraction.
        if let matchedCountry = PodsStore.shared.countries.first(where: {
            $0.localizedCaseInsensitiveCompare(trimmedInput) == .orderedSame
        }) {
            isKeyboardFocused = false
            phase = .searching
            steps = Self.initialSteps()
            // Long enough to see the steps tick, not just a flash.
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            steps[0].title = "Recognized a country."
            steps[0].subtitle = matchedCountry
            steps[0].isDone = true
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            steps[1].subtitle = "Within 50 km of each stop"
            steps[1].isDone = true
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            let found = PodsStore.shared.pods(inCountry: matchedCountry, type: nil)
            // No stop to measure from: the pick is the pod with the most beds.
            let byBeds = found.sorted { ($0.bedsTotal ?? 0) > ($1.bedsTotal ?? 0) }
            let reason = byBeds.first?.bedsTotal.map { "Most beds in \(matchedCountry), \($0)" }
            journeyStops = [JourneyStop(name: matchedCountry, pods: byBeds, isResolved: true, pickReason: reason)]
            steps[2].subtitle = "Your plan is ready"
        steps[2].isDone = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            phase = .results
            return
        }
        
        isKeyboardFocused = false
        phase = .searching
        errorMessage = nil
        steps = Self.initialSteps()
        // A beat on the first step before it resolves.
        try? await Task.sleep(nanoseconds: 600_000_000)
        guard !Task.isCancelled else { return }
        
        // Step 1 — extract place names on-device.
        var placeNames = LennyItineraryParser.extractPlaceNames(from: itineraryText)
        if placeNames.isEmpty {
            // NLTagger needs sentence context and often misses short or
            // single-word input ("Chamonix" alone, no surrounding text).
            // Fall back to treating the whole trimmed input as one place.
            placeNames = [trimmedInput]
        }
        guard !placeNames.isEmpty else {
            errorMessage = "Couldn't find any place names in that — try naming a peak, lake, or town."
            phase = .editing
            return
        }
        steps[0].title = "Extracting \(Self.stopCount(placeNames.count))."
        steps[0].subtitle = placeNames.joined(separator: ", ")
        steps[0].isDone = true
        try? await Task.sleep(nanoseconds: 700_000_000) // keeps the step readable, not just a flash
        guard !Task.isCancelled else { return }

        steps[1].subtitle = "Within 50 km of each stop"
        steps[1].isDone = true
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else { return }

        // The last step stays "loading" while each stop is resolved to
        // its pods, one at a time; the plan opens once they all are.
        journeyStops = placeNames.map { JourneyStop(name: $0, pods: [], isResolved: false) }
        for (index, name) in placeNames.enumerated() {
            guard let result = await LennyItineraryParser.geocode(name), !Task.isCancelled else { continue }
            let stopLocation = CLLocation(latitude: result.coordinate.latitude, longitude: result.coordinate.longitude)
            var distances: [UUID: Double] = [:]
            for pod in PodsStore.shared.pods(near: [result.coordinate], radiusKm: 50) {
                guard let lat = pod.latitude, let lng = pod.longitude else { continue }
                distances[pod.id] = CLLocation(latitude: lat, longitude: lng).distance(from: stopLocation) / 1000
            }
            // Closest first; the lead pod is Lenny's pick.
            let found = PodsStore.shared.pods
                .filter { distances[$0.id] != nil }
                .sorted { distances[$0.id, default: 0] < distances[$1.id, default: 0] }
            journeyStops[index] = JourneyStop(
                name: name, pods: found, isResolved: true,
                distancesKm: distances,
                pickReason: found.first == nil ? nil : "Closest to \(name)"
            )
        }
        guard !Task.isCancelled else { return }

        steps[2].subtitle = "Your plan is ready"
        steps[2].isDone = true
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else { return }

        if journeyStops.allSatisfy({ $0.pods.isEmpty }) {
            errorMessage = "Couldn't find any podz along that route."
        }
        phase = .results
    }

    /// "one stop", "three stops", "12 stops" — the step title's wording.
    private static func stopCount(_ count: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        let number = count < words.count ? words[count] : "\(count)"
        return "\(number) \(count == 1 ? "stop" : "stops")"
    }
}

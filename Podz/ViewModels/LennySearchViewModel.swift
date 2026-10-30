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
    
    /// One row in the results journey timeline — a stop that was
    /// extracted from the itinerary, resolved one at a time so the UI
    /// can reveal counts progressively rather than all at once.
    struct JourneyStop: Identifiable {
        let id = UUID()
        var name: String
        var podsFound: Int
        var isResolved: Bool
    }
    
    @Published var phase: Phase = .idle
    @Published var itineraryText = ""
    @Published var steps: [StepInfo] = []
    @Published var matchingPods: [Pod] = []
    @Published var journeyStops: [JourneyStop] = []
    @Published var selectedPodIDs: Set<UUID> = []
    @Published var errorMessage: String?
    @Published var isKeyboardFocused = false
    private var dismissTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    
    func toggleSelection(for pod: Pod) {
        if selectedPodIDs.contains(pod.id) {
            selectedPodIDs.remove(pod.id)
        } else {
            selectedPodIDs.insert(pod.id)
        }
    }
    
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
            matchingPods = []
            journeyStops = []
            selectedPodIDs = []
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
        matchingPods = []
        journeyStops = []
        selectedPodIDs = []
        errorMessage = nil
    }
    
    /// Starts a search for `text` in a task the view model owns, so leaving
    /// the screen (`forceReset`) also stops the steps still ticking.
    func start(_ text: String) {
        searchTask?.cancel()
        itineraryText = text
        searchTask = Task { await submit() }
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
            try? await Task.sleep(nanoseconds: 300_000_000)
            phase = .searching
            steps = [
                StepInfo(id: 0, title: "Recognized a country.", subtitle: matchedCountry, isDone: true)
            ]
            // Long enough to actually read the single step, not just
            // register a flash before results replace it — this is the
            // fast path's whole "searching" phase, so it's the only
            // chance to see it happen at all.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            let found = PodsStore.shared.pods(inCountry: matchedCountry, type: nil)
            matchingPods = found
            journeyStops = [JourneyStop(name: matchedCountry, podsFound: found.count, isResolved: true)]
            phase = .results
            return
        }
        
        isKeyboardFocused = false
        try? await Task.sleep(nanoseconds: 300_000_000)
        phase = .searching
        errorMessage = nil
        
        steps = [
            StepInfo(id: 0, title: "Extracting your stops.", subtitle: "Reading your itinerary…", isDone: false),
            StepInfo(id: 1, title: "Finding the best pods around here.", subtitle: "Within 50 km of each stop", isDone: false),
            StepInfo(id: 2, title: "Loading your itinerary.", subtitle: "Can take up to 2 minutes…", isDone: false)
        ]
        
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

        steps[1].isDone = true
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else { return }
        steps[2].isDone = true
        // Same 700ms as the other two, not the original 300 — all
        // three steps used to fly by in ~1s total, too fast to read
        // any of them before results replaced the list outright.
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else { return }
        
        // Switch to the results screen now, then resolve each stop one
        // at a time — the journey timeline fills in live rather than
        // waiting for every stop before showing anything.
        journeyStops = placeNames.map { JourneyStop(name: $0, podsFound: 0, isResolved: false) }
        phase = .results
        
        var allFound: [Pod] = []
        for (index, name) in placeNames.enumerated() {
            guard let result = await LennyItineraryParser.geocode(name), !Task.isCancelled else { continue }
            let found = PodsStore.shared.pods(near: [result.coordinate], radiusKm: 50)
            allFound.append(contentsOf: found)
            journeyStops[index] = JourneyStop(name: result.region, podsFound: found.count, isResolved: true)
            matchingPods = allFound
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        if allFound.isEmpty {
            errorMessage = "Couldn't find any podz along that route."
        }
    }

    /// "one stop", "three stops", "12 stops" — the step title's wording.
    private static func stopCount(_ count: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        let number = count < words.count ? words[count] : "\(count)"
        return "\(number) \(count == 1 ? "stop" : "stops")"
    }
}

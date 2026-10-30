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
        var pods: [Pod]
        var isResolved: Bool
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
            journeyStops = [JourneyStop(name: matchedCountry, pods: found, isResolved: true)]
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

        // The last step stays "loading" while each stop is resolved to
        // its pods, one at a time; the plan opens once they all are.
        journeyStops = placeNames.map { JourneyStop(name: $0, pods: [], isResolved: false) }
        for (index, name) in placeNames.enumerated() {
            guard let result = await LennyItineraryParser.geocode(name), !Task.isCancelled else { continue }
            let found = PodsStore.shared.pods(near: [result.coordinate], radiusKm: 50)
            journeyStops[index] = JourneyStop(name: name, pods: found, isResolved: true)
        }
        guard !Task.isCancelled else { return }

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

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
    
    /// Immediate reset, no animation delay — used as a safety net (e.g.
    /// recovering from an app-background/foreground edge case), unlike
    /// `cancel()` which deliberately waits for the keyboard to finish
    /// dismissing before clearing state.
    func forceReset() {
        dismissTask?.cancel()
        isKeyboardFocused = false
        phase = .idle
        itineraryText = ""
        steps = []
        matchingPods = []
        journeyStops = []
        selectedPodIDs = []
        errorMessage = nil
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
                StepInfo(id: 0, title: "Recognized a country", subtitle: matchedCountry, isDone: true)
            ]
            try? await Task.sleep(nanoseconds: 500_000_000)
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
            StepInfo(id: 0, title: "Extracting stops", subtitle: "Reading your itinerary...", isDone: false),
            StepInfo(id: 1, title: "Finding the best podz around each stop", subtitle: "", isDone: false),
            StepInfo(id: 2, title: "Loading your itinerary...", subtitle: "Can take up to 2 minutes", isDone: false)
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
        steps[0].subtitle = placeNames.joined(separator: ", ")
        steps[0].isDone = true
        try? await Task.sleep(nanoseconds: 400_000_000) // keeps the step readable, not just a flash
        
        steps[1].isDone = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        steps[2].isDone = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Switch to the results screen now, then resolve each stop one
        // at a time — the journey timeline fills in live rather than
        // waiting for every stop before showing anything.
        journeyStops = placeNames.map { JourneyStop(name: $0, podsFound: 0, isResolved: false) }
        phase = .results
        
        var allFound: [Pod] = []
        for (index, name) in placeNames.enumerated() {
            guard let result = await LennyItineraryParser.geocode(name) else { continue }
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
}

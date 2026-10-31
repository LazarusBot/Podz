import SwiftUI
import Combine

/// Lenny's booking flow, as a model the Lenny plan's summary and the pod
/// detail both use (`LennySummaryView`, `MinimalPodDetailView`).
///
/// One question at a time: **guests**, the **start date**, the **nights** (per
/// stop when there are several), then **Reserve**. Answers can come in already
/// from what the user said to Lenny (`LennyRequest`). Each answer becomes a
/// chip to change on its own. Booking goes stop by stop and stops at the first
/// that doesn't go through, so a retry only books what's left.
@MainActor
final class BookingFlow: ObservableObject {
    /// The questions, in order.
    enum Stage: Int {
        case guests, date, nights, review
    }

    enum Status: Equatable {
        case idle
        case booking
        case booked
        case failed(String)
    }

    struct QuickReply {
        let title: String
        let action: () -> Void
    }

    static let maxNights = 7

    let entries: [LennySummaryView.Entry]
    let request: LennyRequest?
    /// The pod's live free beds when it's a single pod, so the guest picker's
    /// ceiling is what the server will accept.
    @Published var liveBedsAvailable: Int?

    @Published var startDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @Published var guests = 1
    @Published var nights = 1
    /// Nights for each stop when they're set one by one; `nights` applies to
    /// all of them otherwise.
    @Published var nightsByStop: [Int] = []
    @Published var usesPerStop = false
    /// Which stop the nights picker is changing: nil is all of them.
    @Published var nightsScope: Int?
    @Published var stage = Stage.guests
    /// On a question: false shows a plain button ("Add guest", "Add date"),
    /// true opens the picker across the whole stack.
    @Published var isPicking = false
    /// Set once a question has been answered with the continue button.
    @Published var guestsConfirmed = false
    @Published var dateConfirmed = false
    @Published var nightsConfirmed = false
    @Published var status = Status.idle
    @Published var showsDatePicker = false

    /// Stops already booked, so a retry only books what's left.
    private var bookedPodIDs: Set<UUID> = []
    private let reservationsStore = ReservationsStore.shared

    init(entries: [LennySummaryView.Entry], request: LennyRequest? = nil) {
        self.entries = entries
        self.request = request
        applyRequest()
    }

    /// Starts over, for a new booking on the same screen.
    func restart() {
        startDate = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        guests = 1
        usesPerStop = false
        nightsScope = nil
        isPicking = false
        guestsConfirmed = false
        dateConfirmed = false
        nightsConfirmed = false
        status = .idle
        bookedPodIDs = []
        applyRequest()
    }

    // MARK: - Answers

    var isSingle: Bool { entries.count == 1 }

    func nightsFor(_ index: Int) -> Int {
        usesPerStop && nightsByStop.indices.contains(index) ? nightsByStop[index] : nights
    }

    var isPickerOpen: Bool { isPicking && status != .booking && status != .booked }

    var hasChoices: Bool { guestsConfirmed || dateConfirmed || nightsConfirmed }

    /// The tightest bed count among the picked pods (and, for one pod, what's
    /// free now).
    var maxGuests: Int {
        var cap = max(1, min(8, entries.compactMap(\.pod.bedsTotal).min() ?? 8))
        if isSingle, let live = liveBedsAvailable { cap = min(cap, max(live, 1)) }
        return cap
    }

    var today: Date { Calendar.current.startOfDay(for: Date()) }

    var canGoEarlier: Bool { startDate > today }

    func shifted(_ date: Date, by days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Each stop starts where the one before it ends, in route order.
    func date(forStop index: Int) -> Date {
        shifted(startDate, by: (0..<index).reduce(0) { $0 + nightsFor($1) })
    }

    /// The stops show their dates once the start and the nights are answered.
    var showsDates: Bool { dateConfirmed && nightsConfirmed }

    var guestsText: String { "\(guests) \(guests == 1 ? "guest" : "guests")" }

    var dateText: String {
        startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "2 nights per stop", or "2 · 3 · 1 nights" when they differ.
    var nightsText: String {
        if usesPerStop {
            return entries.indices.map { "\(nightsFor($0))" }.joined(separator: " · ") + " nights"
        }
        let base = "\(nights) \(nights == 1 ? "night" : "nights")"
        return isSingle ? base : base + " per stop"
    }

    var totalNights: Int { entries.indices.reduce(0) { $0 + nightsFor($1) } }

    /// Only partner huts are booked in the app; a listed one is booked through
    /// the hut itself.
    var bookableCount: Int { entries.filter(\.pod.isBookable).count }

    private var listedNote: String? {
        let listed = entries.filter { !$0.pod.isBookable }.map(\.pod.name)
        switch listed.count {
        case 0: return nil
        case 1: return "\(listed[0]) is listed only, so book it through the hut."
        default: return "\(listed.count) of the huts are listed only, so book them through the huts."
        }
    }

    /// How many nights each stop probably gets, from the stay the user gave.
    private var suggestedNights: Int? {
        request?.suggestedNightsPerStop(stops: entries.count, maximum: Self.maxNights)
    }

    /// What the user already said: guests and the start date are answered
    /// before the questions start, and stay on screen as chips to change.
    private func applyRequest() {
        nights = suggestedNights ?? 1
        nightsByStop = Array(repeating: nights, count: entries.count)
        if let said = request?.guests {
            guests = min(max(1, said), maxGuests)
            guestsConfirmed = true
        }
        if let said = request?.startDate {
            startDate = max(said, today)
            dateConfirmed = true
        }
        stage = !guestsConfirmed ? .guests : (!dateConfirmed ? .date : .nights)
        // Nothing here to book in the app: no questions to ask.
        if bookableCount == 0 { stage = .review }
    }

    // MARK: - Steering

    /// The nights question is asked for all the stops at once; with two or
    /// more stops Lenny offers to ask stop by stop instead, and while it does,
    /// a way to go back a stop or to the single number.
    var quickReply: QuickReply? {
        guard stage == .nights, status == .idle, entries.count > 1 else { return nil }
        guard let stop = nightsScope else {
            return QuickReply(title: "Set each stop") { [weak self] in self?.startPerStopNights() }
        }
        if stop == 0 {
            return QuickReply(title: "Same for every stop") { [weak self] in
                self?.nightsScope = nil
                self?.usesPerStop = false
            }
        }
        return QuickReply(title: "Previous stop") { [weak self] in self?.nightsScope = stop - 1 }
    }

    /// Lenny asks the nights one stop at a time, starting with the first.
    private func startPerStopNights() {
        nightsByStop = Array(repeating: nights, count: entries.count)
        usesPerStop = true
        nightsScope = 0
        isPicking = true
    }

    /// Changes the nights of the stop Lenny is asking about, or of all of them
    /// (which also makes them equal again).
    private func adjustNights(by delta: Int) {
        if let stop = nightsScope, nightsByStop.indices.contains(stop) {
            if !usesPerStop {
                nightsByStop = Array(repeating: nights, count: entries.count)
                usesPerStop = true
            }
            nightsByStop[stop] = min(max(1, nightsByStop[stop] + delta), Self.maxNights)
        } else {
            nights = min(max(1, nights + delta), Self.maxNights)
            usesPerStop = false
        }
    }

    func decrease() {
        switch stage {
        case .guests: if guests > 1 { guests -= 1 }
        case .nights: adjustNights(by: -1)
        default: if canGoEarlier { startDate = shifted(startDate, by: -1) }
        }
    }

    func increase() {
        switch stage {
        case .guests: if guests < maxGuests { guests += 1 }
        case .nights: adjustNights(by: 1)
        default: startDate = shifted(startDate, by: 1)
        }
    }

    /// Answers the question, then goes to the next one still unanswered, or to
    /// the review when they're all answered (also after changing one answer).
    func confirm() {
        // Asking stop by stop: next stop, until the last.
        if stage == .nights, let stop = nightsScope, stop + 1 < entries.count {
            nightsScope = stop + 1
            return
        }
        isPicking = false
        nightsScope = nil
        switch stage {
        case .guests: guestsConfirmed = true
        case .date: dateConfirmed = true
        case .nights: nightsConfirmed = true
        case .review: break
        }
        if !guestsConfirmed {
            stage = .guests
        } else if !dateConfirmed {
            stage = .date
        } else if !nightsConfirmed {
            stage = .nights
        } else {
            stage = .review
        }
    }

    /// Back steps back through the questions; from the first (or once booked),
    /// it leaves.
    func back(onLeave: () -> Void) {
        guard status != .booking else { return }
        if status == .booked {
            onLeave()
        } else if let previous = Stage(rawValue: stage.rawValue - 1) {
            status = .idle
            isPicking = false
            stage = previous
        } else {
            onLeave()
        }
    }

    /// A tap on a chip changes that answer on its own.
    func change(_ target: Stage) {
        guard status != .booking, status != .booked else { return }
        status = .idle
        stage = target
        // Nights set stop by stop reopen stop by stop.
        nightsScope = target == .nights && usesPerStop ? 0 : nil
        isPicking = true
    }

    // MARK: - Lenny

    var mood: LennyMood {
        switch status {
        case .booked: .happy
        case .failed: .sorry
        case .idle, .booking: .working
        }
    }

    /// Lenny's line: the question, then the answer. `nil` (typing dots) while
    /// it books.
    var replyMessage: String? {
        if bookableCount == 0 {
            return "These huts take their bookings themselves. Open one to call, email or visit its site."
        }
        return switch status {
        case .booking: nil
        case .booked:
            "Booked! \(totalNights) \(totalNights == 1 ? "night" : "nights") for \(guestsText), all set.\(listedNote.map { " " + $0 } ?? "")"
        case .failed(let message): message
        case .idle:
            switch stage {
            case .guests: "How many of you are going?"
            case .date: isSingle ? "And when do you arrive?" : "And when do you start?"
            case .nights:
                if let stop = nightsScope {
                    stop == 0 ? "How many nights at \(entries[stop].stopName)?" : "And at \(entries[stop].stopName)?"
                } else if isSingle {
                    "And for how many nights?"
                } else if let suggestion = suggestedNights {
                    "I'd say \(suggestion) \(suggestion == 1 ? "night" : "nights") per stop. Does that work?"
                } else {
                    "How many nights per stop?"
                }
            case .review: "\(totalNights) \(totalNights == 1 ? "night" : "nights") for \(guestsText), from \(dateText). Shall I book it?\(listedNote.map { " " + $0 } ?? "")"
            }
        }
    }

    // MARK: - Booking

    /// Books each stop that isn't booked yet, in order, and stops at the
    /// first one that doesn't go through.
    func reserve() {
        status = .booking
        Task {
            // A beat of typing dots, so it reads as Lenny doing it.
            try? await Task.sleep(nanoseconds: 700_000_000)
            for (index, entry) in entries.enumerated() where entry.pod.isBookable && !bookedPodIDs.contains(entry.pod.id) {
                let checkIn = date(forStop: index)
                let checkOut = shifted(checkIn, by: nightsFor(index))
                let success = await reservationsStore.create(podId: entry.pod.id, checkIn: checkIn, checkOut: checkOut, guests: guests)
                guard success else {
                    let booked = bookedPodIDs.count
                    let started = booked == 0 ? "" : "I booked \(booked) of \(bookableCount). "
                    status = .failed("\(started)I couldn't book \(entry.pod.name) for \(checkIn.formatted(.dateTime.day().month(.abbreviated))). It may be full, so try other dates.")
                    return
                }
                bookedPodIDs.insert(entry.pod.id)
            }
            status = .booked
        }
    }
}

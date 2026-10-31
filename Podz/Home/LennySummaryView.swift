import SwiftUI

/// The end of the Lenny plan: the pod picked at each stop, in route order,
/// along the same numbered line as the search's steps. Same page recipe as
/// the pages Profile opens (`design.md`): a 30 semiBold title, the list
/// behind a fade into the ground, and the control stack at the bottom.
/// Tap a row to look at that pod.
///
/// It's also where the plan gets booked, one question at a time, with Lenny
/// asking in its bubble above the control stack: **guests**, the **start
/// date**, the **nights at each stop** (Lenny suggests a number from the
/// route), then **Reserve**. Each question is first a plain button ("Add
/// guest", "Add date", "Add nights") beside the back pill; tapping it opens
/// the picker across the whole stack (a round minus, the answer, a round plus
/// and the continue button; tap the date for a calendar). Every answer then
/// shows as a chip under the title, and a tap on a chip changes that answer on
/// its own. The stops take their dates from the start date and the nights, in
/// route order. Lenny answers while it books (typing, then a happy "booked" or
/// a sorry "couldn't"), and once they're booked the pill becomes **View
/// reservations**. Back steps back through the questions.
struct LennySummaryView: View {
    struct Entry: Identifiable {
        let stopName: String
        let pod: Pod
        /// "3.2 km away · 24 beds"; may be empty.
        let detail: String
        let isLennysPick: Bool
        var id: UUID { pod.id }
    }

    let entries: [Entry]
    let photoURLs: [UUID: String]
    var onBack: () -> Void
    var onOpenPod: (Pod) -> Void
    /// After booking: go look at the reservations.
    var onViewReservations: () -> Void
    /// What Lenny understood from the user's sentence: guests and the start
    /// date prefill the booking (shown as chips), the stay suggests the nights.
    var request: LennyRequest?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var reservationsStore = ReservationsStore.shared
    @State private var appeared = false
    @State private var showsDatePicker = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var guests = 1
    @State private var nights = 1
    /// Nights for each stop when they're set one by one (tap the nights
    /// number in the picker); `nights` applies to all of them otherwise.
    @State private var nightsByStop: [Int] = []
    @State private var usesPerStop = false
    /// Which stop the nights picker is changing: nil is all of them.
    @State private var nightsScope: Int?
    @State private var didApplyRequest = false
    @State private var stage = Stage.guests
    /// On a question: false shows a plain button ("Add guest", "Add date"),
    /// true opens the picker across the whole stack.
    @State private var isPicking = false
    /// Set once a question has been answered with the continue button.
    @State private var guestsConfirmed = false
    @State private var dateConfirmed = false
    @State private var nightsConfirmed = false
    @State private var status = BookingStatus.idle
    /// Stops already booked, so a retry only books what's left.
    @State private var bookedPodIDs: Set<UUID> = []

    /// The questions, in order.
    private enum Stage: Int {
        case guests, date, nights, review
    }

    private enum BookingStatus: Equatable {
        case idle
        case booking
        case booked
        case failed(String)
    }

    private let dotSize: CGFloat = 24
    private let photoSize: CGFloat = 88

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your plan")
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(-0.6)
                        .foregroundColor(.homeText)
                        .padding(.horizontal, 24)
                        .padding(.top, 25)

                    Text(subtitle)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, hasChoices ? 16 : 28)

                    choiceChips

                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry, number: index + 1, isLast: index == entries.count - 1, date: showsDates ? date(forStop: index) : nil, nights: nightsFor(index))
                            // Each stop settles in a beat after the one before.
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .offset(y: appeared || reduceMotion ? 0 : 14)
                            .animation(.smooth(duration: 0.5).delay(0.08 * Double(index)), value: appeared)
                    }

                    // Room under the list for the pills and Lenny's bubble.
                    Color.clear.frame(height: 250 + (quickReply != nil ? 36 : 0))
                }
            }

            BottomFade()

            // Lenny's line, and under it, when there's one, a quick reply.
            VStack(alignment: .leading, spacing: 8) {
                LennyReply(message: replyMessage, mood: mood)
                if let reply = quickReply {
                    quickReplyPill(reply)
                        // Lined up with the bubble's text, past the avatar.
                        .padding(.leading, 38 + 18)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 24)
            // Just above the control stack.
            .padding(.bottom, 40 + 83 + 20)

            // The control stack. Resting: back and the pill (a plain button
            // for the question, then Reserve). While a picker is open it takes
            // the whole stack: minus, the answer, plus, continue.
            HStack(spacing: 13) {
                if isPickerOpen {
                    picker
                        .transition(.opacity)
                } else {
                    DetailBackButton(action: back)
                    primaryPill
                }
            }
            .padding(.horizontal, 24)
            // The cover respects the safe area, so 40 here is the 74 from
            // the bottom edge every control stack uses.
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.35), value: stage)
        .animation(.smooth(duration: 0.35), value: isPicking)
        .animation(.smooth(duration: 0.35), value: nightsScope)
        .animation(.smooth(duration: 0.35), value: status)
        .animation(.smooth(duration: 0.35), value: guestsConfirmed)
        .animation(.smooth(duration: 0.35), value: dateConfirmed)
        .animation(.smooth(duration: 0.35), value: nightsConfirmed)
        .onAppear {
            appeared = true
            applyRequest()
        }
        .sheet(isPresented: $showsDatePicker) { datePickerSheet }
    }

    // MARK: - The control stack

    /// The right-hand pill at rest: the question as a plain button, then
    /// Reserve / View reservations.
    @ViewBuilder
    private var primaryPill: some View {
        switch (status, stage) {
        case (.booked, _):
            DetailTextButton(title: "View reservations", isHighlighted: true, action: onViewReservations)
        case (.booking, _):
            DetailTextButton(title: "Reserving…", action: {})
                .disabled(true)
                .opacity(0.45)
        case (_, .guests):
            DetailTextButton(title: guestsConfirmed ? "\(guests) \(guests == 1 ? "guest" : "guests")" : "Add guest") {
                isPicking = true
            }
        case (_, .date):
            DetailTextButton(title: dateConfirmed ? startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) : "Add date") {
                isPicking = true
            }
        case (_, .nights):
            DetailTextButton(title: nightsConfirmed ? nightsText : "Add nights") {
                isPicking = true
            }
        case (_, .review):
            DetailTextButton(title: "Reserve", isHighlighted: true, action: reserve)
        }
    }

    /// The picker, across the whole stack: one big pill holding a round minus,
    /// the answer and a round plus (the two buttons are 75, 4 in from the
    /// pill's edge all round), then continue beside it.
    private var picker: some View {
        HStack(spacing: 13) {
            HStack(spacing: 0) {
                pickerButton(accessibilityLabel: lessLabel, action: decrease) {
                    MinusGlyph()
                }

                Group {
                    switch stage {
                    case .guests:
                        pickerAnswer("\(guests)", caption: guests == 1 ? "guest" : "guests")
                    case .nights:
                        let shown = nightsScope.map(nightsFor) ?? nights
                        pickerAnswer("\(shown)", caption: nightsScope == nil
                            ? (shown == 1 ? "night per stop" : "nights per stop")
                            : (shown == 1 ? "night" : "nights"))
                    default:
                        // Tap the date for the calendar, to jump further.
                        Button { showsDatePicker = true } label: {
                            VStack(spacing: 2) {
                                Text(startDate.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(AppFont.semiBoldLabel(16))
                                    .foregroundColor(.homeText)
                                Text(startDate.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(AppFont.regularLabel(12))
                                    .foregroundColor(.homeSubtitle)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start date, \(startDate.formatted(.dateTime.weekday(.wide).day().month(.wide))). Opens the calendar")
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

                pickerButton(accessibilityLabel: moreLabel, action: increase) {
                    PlusGlyph()
                }
            }
            // 4 all round, so the 75 circles sit evenly inside the 83 pill.
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 83)
            .background(DetailPill())

            continueButton
        }
    }

    /// A − or + at the end of the picker pill: a 75 circle in the classic
    /// pill grey with a 0.5pt edge so it reads against the pill, and a thin
    /// vector like the back chevron's.
    private func pickerButton<Glyph: Shape>(
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder glyph: () -> Glyph
    ) -> some View {
        Button(action: action) {
            glyph()
                .stroke(Color.homeText, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 12, height: 12)
                .frame(width: 75, height: 75)
                .background(Color.homePill, in: Circle())
                .overlay(Circle().strokeBorder(Color.homeText.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var lessLabel: String {
        switch stage {
        case .guests: "Fewer guests"
        case .nights: "Fewer nights"
        default: "Day earlier"
        }
    }

    private var moreLabel: String {
        switch stage {
        case .guests: "More guests"
        case .nights: "More nights"
        default: "Day later"
        }
    }

    private func pickerAnswer(_ value: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.semiBoldLabel(24))
                .foregroundColor(.homeText)
            Text(caption)
                .font(AppFont.regularLabel(12))
                .foregroundColor(.homeSubtitle)
        }
    }

    private func nightsFor(_ index: Int) -> Int {
        usesPerStop && nightsByStop.indices.contains(index) ? nightsByStop[index] : nights
    }

    private var isPickerOpen: Bool { isPicking && status != .booking && status != .booked }

    // MARK: - Lenny's quick reply

    private struct QuickReply {
        let title: String
        let action: () -> Void
    }

    /// The nights question is asked for all the stops at once; with two or
    /// more stops Lenny offers to ask stop by stop instead, and while it does,
    /// a way to go back a stop or to the single number.
    private var quickReply: QuickReply? {
        guard stage == .nights, status == .idle, entries.count > 1 else { return nil }
        guard let stop = nightsScope else {
            return QuickReply(title: "Set each stop") { startPerStopNights() }
        }
        if stop == 0 {
            return QuickReply(title: "Same for every stop") {
                nightsScope = nil
                usesPerStop = false
            }
        }
        return QuickReply(title: "Previous stop") { nightsScope = stop - 1 }
    }

    /// A small caption under Lenny's bubble, not a button-shaped control.
    private func quickReplyPill(_ reply: QuickReply) -> some View {
        Button(action: reply.action) {
            HStack(spacing: 5) {
                Text(reply.title)
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .underline(color: Color.homeSubtitle.opacity(0.5))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.homeSubtitle)
            }
            // A comfortable tap area for a small caption.
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func decrease() {
        switch stage {
        case .guests: if guests > 1 { guests -= 1 }
        case .nights: adjustNights(by: -1)
        default: if canGoEarlier { startDate = shifted(startDate, by: -1) }
        }
    }

    private func increase() {
        switch stage {
        case .guests: if guests < maxGuests { guests += 1 }
        case .nights: adjustNights(by: 1)
        default: startDate = shifted(startDate, by: 1)
        }
    }

    /// Answers the question and moves on: the back pill's twin, with its
    /// chevron turned around, inverted because it's the one to press.
    private var continueButton: some View {
        Button(action: confirm) {
            // The back pill's chevron, turned around: same glyph, same size.
            DetailBackChevron()
                .stroke(Color.homeBackground, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 12)
                .scaleEffect(x: -1)
                .frame(width: 83, height: 83)
                .background(Circle().fill(Color.homeText))
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel("Continue")
    }

    /// Answers the question, then goes to the next one still unanswered, or to
    /// the review when they're all answered (also after changing one answer).
    private func confirm() {
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

    /// The calendar, in a small sheet with the same Done pill as everywhere.
    private var datePickerSheet: some View {
        VStack(spacing: 0) {
            DatePicker("", selection: $startDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(.homeText)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            Spacer(minLength: 0)

            DetailTextButton(title: "Done", isHighlighted: true) { showsDatePicker = false }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(Color.homeBackground)
        .presentationDetents([.height(560)])
        .presentationDragIndicator(.hidden)
    }

    /// Back steps back through the questions; from the first, it leaves.
    private func back() {
        guard status != .booking else { return }
        if status == .booked {
            onBack()
        } else if let previous = Stage(rawValue: stage.rawValue - 1) {
            status = .idle
            isPicking = false
            stage = previous
        } else {
            onBack()
        }
    }

    // MARK: - Booking

    /// The tightest bed count among the picked pods.
    private var maxGuests: Int {
        max(1, min(8, entries.compactMap(\.pod.bedsTotal).min() ?? 8))
    }

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var canGoEarlier: Bool { startDate > today }

    private func shifted(_ date: Date, by days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Each stop starts where the one before it ends: `nights` apart, in route
    /// order.
    private func date(forStop index: Int) -> Date {
        shifted(startDate, by: (0..<index).reduce(0) { $0 + nightsFor($1) })
    }

    /// The stops show their dates once the start and the nights are answered.
    private var showsDates: Bool { dateConfirmed && nightsConfirmed }

    private static let maxNights = 7

    private var guestsText: String { "\(guests) \(guests == 1 ? "guest" : "guests")" }

    private var dateText: String {
        startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "2 nights per stop", or "2 · 3 · 1 nights" when they differ.
    private var nightsText: String {
        if usesPerStop {
            return entries.indices.map { "\(nightsFor($0))" }.joined(separator: " · ") + " nights"
        }
        return "\(nights) \(nights == 1 ? "night" : "nights") per stop"
    }

    private var totalNights: Int { entries.indices.reduce(0) { $0 + nightsFor($1) } }

    private var hasChoices: Bool { guestsConfirmed || dateConfirmed || nightsConfirmed }

    /// How many nights each stop probably gets, from the stay the user gave
    /// ("in 5 days" over 3 stops is 2 each); nil when they said nothing.
    private var suggestedNights: Int? {
        request?.suggestedNightsPerStop(stops: entries.count, maximum: Self.maxNights)
    }

    /// What the user already said: guests and the start date are answered
    /// before the questions start, and stay on screen as chips to change.
    private func applyRequest() {
        guard !didApplyRequest else { return }
        didApplyRequest = true
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
    }

    // MARK: - The choices

    /// What's been decided so far, as flat chips under the title. Tap one to
    /// change that answer on its own; the others stay as they are.
    @ViewBuilder
    private var choiceChips: some View {
        if hasChoices {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if guestsConfirmed { chip(guestsText, stage: .guests) }
                    if dateConfirmed { chip(dateText, stage: .date) }
                    if nightsConfirmed { chip(nightsText, stage: .nights) }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
            .transition(.opacity)
        }
    }

    private func chip(_ title: String, stage target: Stage) -> some View {
        Button {
            guard status != .booking, status != .booked else { return }
            status = .idle
            stage = target
            // Nights set stop by stop reopen stop by stop.
            nightsScope = target == .nights && usesPerStop ? 0 : nil
            isPicking = true
        } label: {
            Text(title)
                .font(AppFont.regularLabel(14))
                .foregroundColor(.homeText)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(Capsule().fill(Color.homePill))
        }
        .buttonStyle(TapScaleButtonStyle())
        .disabled(status == .booked)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .accessibilityLabel("\(title). Change")
    }

    private var mood: LennyMood {
        switch status {
        case .booked: .happy
        case .failed: .sorry
        case .idle, .booking: .working
        }
    }

    /// Lenny's line: the question, then the answer. `nil` (typing dots)
    /// while it books.
    private var replyMessage: String? {
        switch status {
        case .booking: nil
        case .booked:
            "Booked! \(totalNights) \(totalNights == 1 ? "night" : "nights") for \(guestsText), all set."
        case .failed(let message): message
        case .idle:
            switch stage {
            case .guests: "How many of you are going?"
            case .date: "And when do you start?"
            case .nights:
                if let stop = nightsScope {
                    stop == 0 ? "How many nights at \(entries[stop].stopName)?" : "And at \(entries[stop].stopName)?"
                } else if let suggestion = suggestedNights {
                    "I'd say \(suggestion) \(suggestion == 1 ? "night" : "nights") per stop. Does that work?"
                } else {
                    "How many nights per stop?"
                }
            case .review: "\(totalNights) \(totalNights == 1 ? "night" : "nights") for \(guestsText), from \(dateText). Shall I book it?"
            }
        }
    }

    /// Books each stop that isn't booked yet, in order, and stops at the
    /// first one that doesn't go through.
    private func reserve() {
        status = .booking
        Task {
            // A beat of typing dots, so it reads as Lenny doing it.
            try? await Task.sleep(nanoseconds: 700_000_000)
            for (index, entry) in entries.enumerated() where !bookedPodIDs.contains(entry.pod.id) {
                let checkIn = date(forStop: index)
                let checkOut = shifted(checkIn, by: nightsFor(index))
                let success = await reservationsStore.create(podId: entry.pod.id, checkIn: checkIn, checkOut: checkOut, guests: guests)
                guard success else {
                    let booked = bookedPodIDs.count
                    let started = booked == 0 ? "" : "I booked \(booked) of \(entries.count). "
                    status = .failed("\(started)I couldn't book \(entry.pod.name) for \(checkIn.formatted(.dateTime.day().month(.abbreviated))). It may be full, so try other dates.")
                    return
                }
                bookedPodIDs.insert(entry.pod.id)
            }
            status = .booked
        }
    }

    private var subtitle: String {
        let stops = entries.count
        return "\(stops) \(stops == 1 ? "stop" : "stops"), one pod each"
    }

    /// "Lake Braies  ·  Mon 2 Nov → Wed 4 Nov" once the dates are known.
    private func stopCaption(_ entry: Entry, from date: Date?, nights: Int) -> String {
        guard let date else { return entry.stopName }
        let format = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
        return "\(entry.stopName)  ·  \(date.formatted(format)) → \(shifted(date, by: nights).formatted(format))"
    }

    /// A numbered dot on the line, then the stop, the pod and its photo.
    private func row(_ entry: Entry, number: Int, isLast: Bool, date: Date?, nights: Int) -> some View {
        Button { onOpenPod(entry.pod) } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Text("\(number)")
                        .font(AppFont.semiBoldLabel(12))
                        .foregroundColor(.homeBackground)
                        .frame(width: dotSize, height: dotSize)
                        .background(Color.homeText, in: Circle())
                    if !isLast {
                        Rectangle()
                            .fill(Color.homeText.opacity(0.25))
                            .frame(width: 1)
                            .mask {
                                // The dotted line the search's steps use.
                                VStack(spacing: 3) {
                                    ForEach(0..<60, id: \.self) { _ in Rectangle().frame(height: 2) }
                                }
                            }
                            .frame(maxHeight: .infinity)
                            .padding(.top, 6)
                    }
                }
                .frame(width: dotSize)

                VStack(alignment: .leading, spacing: 10) {
                    Text(stopCaption(entry, from: date, nights: nights))
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(1)
                        .frame(height: dotSize, alignment: .leading)

                    HStack(alignment: .center, spacing: 16) {
                        Color.clear
                            .frame(width: photoSize, height: photoSize)
                            .overlay { PodPhoto(url: photoURLs[entry.pod.id]) }
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.pod.name)
                                .font(AppFont.semiBoldLabel(17))
                                .foregroundColor(.homeText)
                                .lineLimit(2)
                            if !entry.detail.isEmpty {
                                Text(entry.detail)
                                    .font(AppFont.regularLabel(13))
                                    .foregroundColor(.homeSubtitle)
                                    .lineLimit(1)
                            }
                            if entry.isLennysPick {
                                HStack(spacing: 6) {
                                    Image("lenny")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 10, height: 10)
                                        .foregroundColor(.homeBackground)
                                        .frame(width: 18, height: 18)
                                        .background(Color.homeText, in: Circle())
                                    Text("Lenny's pick")
                                        .font(AppFont.semiBoldLabel(12))
                                        .foregroundColor(.homeText)
                                }
                                .padding(.top, 3)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, isLast ? 0 : 28)
                }
            }
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The thin "-" and "+" of the picker, drawn like the back chevron: 1.5 round
/// strokes in a 12 x 12 box.
private struct MinusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct PlusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = MinusGlyph().path(in: rect)
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

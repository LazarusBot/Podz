import SwiftUI

/// The end of the Lenny plan: the pod picked at each stop, in route order,
/// along the same numbered line as the search's steps. Same page recipe as
/// the pages Profile opens (`design.md`): a 30 semiBold title, the list
/// behind a fade into the ground, and the control stack at the bottom.
/// Tap a row to look at that pod.
///
/// It's also where the plan gets booked, one question at a time in the
/// control stack's right-hand pill, with Lenny asking in its bubble above:
/// **guests** (a stepper in the pill), then the **start date** (a day
/// stepper; tap the date for the calendar), then **Reserve**. Each stop gets
/// one night, in route order. Lenny answers while it books (typing, then a
/// happy "booked" or a sorry "couldn't"), and once they're booked the pill
/// becomes **View reservations**. Back steps back through the questions.
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var reservationsStore = ReservationsStore.shared
    @State private var appeared = false
    @State private var showsDatePicker = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var guests = 1
    @State private var stage = Stage.guests
    @State private var status = BookingStatus.idle
    /// Stops already booked, so a retry only books what's left.
    @State private var bookedPodIDs: Set<UUID> = []

    /// The questions, in order.
    private enum Stage: Int {
        case guests, date, review
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
                        .padding(.bottom, 28)

                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry, number: index + 1, isLast: index == entries.count - 1, date: showsDates ? date(forStop: index) : nil)
                            // Each stop settles in a beat after the one before.
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .offset(y: appeared || reduceMotion ? 0 : 14)
                            .animation(.smooth(duration: 0.5).delay(0.08 * Double(index)), value: appeared)
                    }

                    // Room under the list for the pills and Lenny's bubble.
                    Color.clear.frame(height: 250)
                }
            }

            BottomFade()

            LennyReply(message: replyMessage, mood: mood)
                .padding(.horizontal, 24)
                // Just above the control stack.
                .padding(.bottom, 40 + 83 + 20)

            // The control stack: back, the pill that asks (then books), and
            // while there's a question, a third button to continue.
            HStack(spacing: 13) {
                DetailBackButton(action: back)
                primaryPill
                if showsContinue {
                    continueButton
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            // The cover respects the safe area, so 40 here is the 74 from
            // the bottom edge every control stack uses.
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.35), value: stage)
        .animation(.smooth(duration: 0.35), value: status)
        .onAppear { appeared = true }
        .sheet(isPresented: $showsDatePicker) { datePickerSheet }
    }

    // MARK: - The pill

    /// The question for the current step, or Reserve / View reservations.
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
            askPill(
                decrease: { if guests > 1 { guests -= 1 } },
                increase: { if guests < maxGuests { guests += 1 } },
                decreaseLabel: "Fewer guests",
                increaseLabel: "More guests"
            ) {
                Text("\(guests) \(guests == 1 ? "guest" : "guests")")
                    .font(AppFont.semiBoldLabel(14))
                    .foregroundColor(.homeText)
            }
        case (_, .date):
            askPill(
                decrease: { if canGoEarlier { startDate = shifted(startDate, by: -1) } },
                increase: { startDate = shifted(startDate, by: 1) },
                decreaseLabel: "Day earlier",
                increaseLabel: "Day later"
            ) {
                // Tap the date for the calendar, to jump further.
                Button { showsDatePicker = true } label: {
                    Text(startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(AppFont.semiBoldLabel(14))
                        .foregroundColor(.homeText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start date, \(startDate.formatted(.dateTime.weekday(.wide).day().month(.wide))). Opens the calendar")
            }
        case (_, .review):
            DetailTextButton(title: "Reserve", isHighlighted: true, action: reserve)
        }
    }

    /// The pill while it asks: − / + around the answer. Same 83 high as
    /// every pill in the stack.
    private func askPill<Answer: View>(
        decrease: @escaping () -> Void,
        increase: @escaping () -> Void,
        decreaseLabel: String,
        increaseLabel: String,
        @ViewBuilder answer: () -> Answer
    ) -> some View {
        HStack(spacing: 0) {
            stepButton(systemImage: "minus", label: decreaseLabel, action: decrease)
            answer()
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            stepButton(systemImage: "plus", label: increaseLabel, action: increase)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 83)
        .background(DetailPill())
    }

    /// Moves on to the next question: the back pill's twin, with its chevron
    /// turned around, inverted because it's the one to press.
    private var continueButton: some View {
        Button {
            if let next = Stage(rawValue: stage.rawValue + 1) { stage = next }
        } label: {
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

    /// There's a question on the pill (not Reserve, not while booking or
    /// once it's booked).
    private var showsContinue: Bool {
        status != .booking && status != .booked && stage != .review
    }

    private func stepButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.homeText)
                .frame(width: 34, height: 44)
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel(label)
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

    /// One night per stop, in route order.
    private func date(forStop index: Int) -> Date {
        shifted(startDate, by: index)
    }

    /// The stops show their nights once the date is being chosen.
    private var showsDates: Bool { stage != .guests }

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
            "Booked! \(entries.count) \(entries.count == 1 ? "night" : "nights") for \(guests) \(guests == 1 ? "guest" : "guests"), all set."
        case .failed(let message): message
        case .idle:
            switch stage {
            case .guests: "How many of you are going?"
            case .date: "And when do you start?"
            case .review: "\(entries.count) \(entries.count == 1 ? "night" : "nights") for \(guests) \(guests == 1 ? "guest" : "guests"), from \(startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))). Shall I book it?"
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
                let checkOut = shifted(checkIn, by: 1)
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

    /// A numbered dot on the line, then the stop, the pod and its photo.
    private func row(_ entry: Entry, number: Int, isLast: Bool, date: Date?) -> some View {
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
                    Text(date.map { "\(entry.stopName)  ·  \($0.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))" } ?? entry.stopName)
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

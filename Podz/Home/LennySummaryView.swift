import SwiftUI

/// The end of the Lenny plan: the pod picked at each stop, in route order,
/// along the same numbered line as the search's steps. Same page recipe as
/// the pages Profile opens (`design.md`): a 30 semiBold title, the list
/// behind a fade into the ground, and the back pill with the page's action
/// beside it. Tap a row to look at that pod.
///
/// It's also where the plan gets booked: a start date and a guest count, set
/// right in the control stack, one night per stop in route order, and
/// **Reserve** books them all. Lenny
/// answers in its bubble above the pills (typing while it books, a happy
/// "booked" or a sorry "couldn't"), and once they're booked the pill becomes
/// **View reservations**.
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
    @State private var status = BookingStatus.idle
    /// Stops already booked, so a retry only books what's left.
    @State private var bookedPodIDs: Set<UUID> = []

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
                        row(entry, number: index + 1, isLast: index == entries.count - 1, date: date(forStop: index))
                            // Each stop settles in a beat after the one before.
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .offset(y: appeared || reduceMotion ? 0 : 14)
                            .animation(.smooth(duration: 0.5).delay(0.08 * Double(index)), value: appeared)
                    }

                    // Room under the list for the pills (and Lenny's bubble).
                    Color.clear.frame(height: 190 + (showsOptions ? optionsRowHeight + 13 : 0) + (status == .idle ? 0 : 60))
                }
            }

            BottomFade()

            if status != .idle {
                LennyReply(message: replyMessage, mood: mood)
                    .padding(.horizontal, 24)
                    // Just above the control stack.
                    .padding(.bottom, 40 + 83 + 20 + (showsOptions ? optionsRowHeight + 13 : 0))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // The control stack: when and how many, then back and Reserve.
            VStack(spacing: 13) {
                if showsOptions {
                    optionsRow
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                HStack(spacing: 13) {
                    DetailBackButton(action: onBack)
                    DetailTextButton(title: buttonTitle, isHighlighted: status != .booking, action: buttonTapped)
                        .disabled(status == .booking)
                        .opacity(status == .booking ? 0.45 : 1)
                }
            }
            .padding(.horizontal, 24)
            // The cover respects the safe area, so 40 here is the 74 from
            // the bottom edge every control stack uses.
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.35), value: status)
        .onAppear { appeared = true }
        .sheet(isPresented: $showsDatePicker) { datePickerSheet }
    }

    // MARK: - Booking

    private let optionsRowHeight: CGFloat = 60

    /// Open until it's booked; the choices are final after that.
    private var showsOptions: Bool { status != .booked }

    /// When and how many, as two flat pills right above back / Reserve.
    private var optionsRow: some View {
        HStack(spacing: 13) {
            Button { showsDatePicker = true } label: {
                VStack(spacing: 2) {
                    Text("Starts")
                        .font(AppFont.regularLabel(11))
                        .foregroundColor(.homeSubtitle)
                    Text(startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(AppFont.semiBoldLabel(14))
                        .foregroundColor(.homeText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: optionsRowHeight)
                .background(Capsule().fill(Color.homePill))
            }
            .buttonStyle(TapScaleButtonStyle())
            .accessibilityLabel("Start date, \(startDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))")

            HStack(spacing: 10) {
                stepButton(systemImage: "minus", label: "Fewer guests") { if guests > 1 { guests -= 1 } }
                VStack(spacing: 2) {
                    Text("Guests")
                        .font(AppFont.regularLabel(11))
                        .foregroundColor(.homeSubtitle)
                    Text("\(guests)")
                        .font(AppFont.semiBoldLabel(14))
                        .foregroundColor(.homeText)
                }
                .frame(minWidth: 40)
                stepButton(systemImage: "plus", label: "More guests") { if guests < maxGuests { guests += 1 } }
            }
            .padding(.horizontal, 10)
            .frame(height: optionsRowHeight)
            .background(Capsule().fill(Color.homePill))
        }
        // Not editable while it books.
        .disabled(status == .booking)
        .opacity(status == .booking ? 0.45 : 1)
    }

    private func stepButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.homeText)
                .frame(width: 40, height: 40)
                .background(Color.homeBackground, in: Circle())
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

    /// The tightest bed count among the picked pods.
    private var maxGuests: Int {
        max(1, min(8, entries.compactMap(\.pod.bedsTotal).min() ?? 8))
    }

    /// One night per stop, in route order.
    private func date(forStop index: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? startDate
    }

    private var buttonTitle: String {
        switch status {
        case .idle, .failed: "Reserve"
        case .booking: "Reserving…"
        case .booked: "View reservations"
        }
    }

    private func buttonTapped() {
        if status == .booked { onViewReservations() } else { reserve() }
    }

    private var mood: LennyMood {
        switch status {
        case .booked: .happy
        case .failed: .sorry
        case .idle, .booking: .working
        }
    }

    /// `nil` (typing dots) while it books.
    private var replyMessage: String? {
        switch status {
        case .idle, .booking: nil
        case .booked:
            "Booked! \(entries.count) \(entries.count == 1 ? "night" : "nights") for \(guests) \(guests == 1 ? "guest" : "guests"), all set."
        case .failed(let message): message
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
                let checkOut = Calendar.current.date(byAdding: .day, value: 1, to: checkIn) ?? checkIn
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
    private func row(_ entry: Entry, number: Int, isLast: Bool, date: Date) -> some View {
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
                    Text("\(entry.stopName)  ·  \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
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

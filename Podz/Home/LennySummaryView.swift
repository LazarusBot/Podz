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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The booking questions, answers and the booking itself (`BookingFlow`,
    /// shared with the pod detail).
    @StateObject private var flow: BookingFlow
    @State private var appeared = false

    private let dotSize: CGFloat = 24
    private let photoSize: CGFloat = 88

    /// `request`: what Lenny understood from the user's sentence: guests and
    /// the start date prefill the booking (shown as chips), the stay suggests
    /// the nights.
    init(
        entries: [Entry],
        photoURLs: [UUID: String],
        onBack: @escaping () -> Void,
        onOpenPod: @escaping (Pod) -> Void,
        onViewReservations: @escaping () -> Void,
        request: LennyRequest? = nil
    ) {
        self.entries = entries
        self.photoURLs = photoURLs
        self.onBack = onBack
        self.onOpenPod = onOpenPod
        self.onViewReservations = onViewReservations
        _flow = StateObject(wrappedValue: BookingFlow(entries: entries, request: request))
    }

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
                        .padding(.bottom, flow.hasChoices ? 16 : 28)

                    if flow.hasChoices {
                        BookingChips(flow: flow)
                            .padding(.bottom, 24)
                    }

                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry, number: index + 1, isLast: index == entries.count - 1, date: flow.showsDates ? flow.date(forStop: index) : nil, nights: flow.nightsFor(index))
                            // Each stop settles in a beat after the one before.
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .offset(y: appeared || reduceMotion ? 0 : 14)
                            .animation(.smooth(duration: 0.5).delay(0.08 * Double(index)), value: appeared)
                    }

                    // Room under the list for the pills and Lenny's bubble.
                    Color.clear.frame(height: 250 + (flow.quickReply != nil ? 36 : 0))
                }
            }

            BottomFade()

            // Lenny's line, and under it, when there's one, a quick reply.
            VStack(alignment: .leading, spacing: 8) {
                LennyReply(message: flow.replyMessage, mood: flow.mood)
                if let reply = flow.quickReply {
                    BookingQuickReply(reply: reply)
                        // Lined up with the bubble's text, past the avatar.
                        .padding(.leading, 38 + 18)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 24)
            // Just above the control stack.
            .padding(.bottom, 40 + 83 + 20)

            // The control stack (`BookingControlStack`). The cover respects the
            // safe area, so 40 here is the 74 from the bottom edge every
            // control stack uses.
            BookingControlStack(flow: flow, onLeave: onBack, onViewReservations: onViewReservations)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.35), value: flow.stage)
        .animation(.smooth(duration: 0.35), value: flow.nightsScope)
        .animation(.smooth(duration: 0.35), value: flow.status)
        .animation(.smooth(duration: 0.35), value: flow.guestsConfirmed)
        .animation(.smooth(duration: 0.35), value: flow.dateConfirmed)
        .animation(.smooth(duration: 0.35), value: flow.nightsConfirmed)
        .onAppear { appeared = true }
    }

    private var subtitle: String {
        let stops = entries.count
        return "\(stops) \(stops == 1 ? "stop" : "stops"), one pod each"
    }

    /// "Lake Braies  ·  Mon 2 Nov → Wed 4 Nov" once the dates are known.
    private func stopCaption(_ entry: Entry, from date: Date?, nights: Int) -> String {
        guard let date else { return entry.stopName }
        let format = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
        return "\(entry.stopName)  ·  \(date.formatted(format)) → \(flow.shifted(date, by: nights).formatted(format))"
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
                            .overlay { PodPhoto(url: photoURLs[entry.pod.id], coordinate: entry.pod.coordinate) }
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
                            if !entry.pod.isBookable {
                                Text("Listed  ·  book through the hut")
                                    .font(AppFont.regularLabel(12))
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

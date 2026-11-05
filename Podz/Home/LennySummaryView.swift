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
        /// The day from the last hut on a route across an area, when there is one.
        var stage: LennyStage?
        var id: UUID { pod.id }
    }

    let entries: [Entry]
    let photoURLs: [UUID: String]
    var onBack: () -> Void
    var onOpenPod: (Pod) -> Void
    /// After booking: go look at the reservations.
    var onViewReservations: () -> Void
    /// The route comes back to its first hut.
    var isLoop = false
    /// What the plan is called when saved ("Across the Alps").
    var planTitle: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The booking questions, answers and the booking itself (`BookingFlow`,
    /// shared with the pod detail).
    @StateObject private var flow: BookingFlow
    @State private var appeared = false
    /// The hiking trails between the huts, found once the page is up.
    @StateObject private var trails = LennyRouteTracks()
    @ObservedObject private var savedPlans = SavedPlansStore.shared
    /// List (the stops) or Map (the trace of the route).
    @State private var showsMap = false

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
        request: LennyRequest? = nil,
        isLoop: Bool = false,
        planTitle: String? = nil
    ) {
        self.isLoop = isLoop
        self.planTitle = planTitle
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
                    T("Your plan")
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(-0.6)
                        .foregroundColor(.homeText)
                        .padding(.horizontal, 24)
                        .padding(.top, 25)

                    T(subtitle)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, 16)

                    // List or Map, and keep the plan without booking it.
                    HStack {
                        if hasPath { PlanModeToggle(showsMap: $showsMap) }
                        Spacer(minLength: 0)
                        SavePlanCaption(isSaved: savedPlan != nil, action: toggleSaved)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, flow.hasChoices ? 14 : 20)

                    if flow.hasChoices {
                        BookingChips(flow: flow)
                            .padding(.bottom, 24)
                    }

                    if showsMap && hasPath {
                        routeMap
                    } else {
                        stopsList
                    }

                    // Room under the list for the pills and Lenny's bubble.
                    Color.clear.frame(height: 190 + (flow.quickReply != nil ? 36 : 0))
                }
            }

            // Lenny's bubble floats above the pills: the fade rises with it
            // (the whole-screen fade, a little higher with a quick reply).
            SectionFadeLayer(fade: flow.quickReply == nil ? .tall : SectionFade(start: 0.62, solid: 0.83))

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
            .padding(.bottom, DetailLayout.controlStackGap + 83 + 20)

            // The control stack (`BookingControlStack`). The cover respects the
            // safe area, so 40 here is the 74 from the bottom edge every
            // control stack uses.
            BookingControlStack(flow: flow, onLeave: onBack, onViewReservations: onViewReservations)
                .padding(.horizontal, 24)
                .padding(.bottom, DetailLayout.controlStackGap)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.35), value: flow.stage)
        .animation(.smooth(duration: 0.35), value: flow.nightsScope)
        .animation(.smooth(duration: 0.35), value: flow.status)
        .animation(.smooth(duration: 0.35), value: flow.guestsConfirmed)
        .animation(.smooth(duration: 0.35), value: flow.dateConfirmed)
        .animation(.smooth(duration: 0.35), value: flow.nightsConfirmed)
        .onAppear { appeared = true }
        .task { await trails.load(legs: legs) }
    }

    /// The pairs of huts a trail is looked for between (and the way back, for a loop).
    private var legs: [(Pod, Pod)] {
        var pairs = Array(zip(entries.map(\.pod), entries.dropFirst().map(\.pod)))
        if isLoop, entries.count > 2, let last = entries.last?.pod, let first = entries.first?.pod { pairs.append((last, first)) }
        return pairs
    }

    /// The day into hut `index`: along the real trail when it's found, else the estimate.
    private func stage(into index: Int) -> LennyStage? {
        if index > 0, let track = trails.tracks[LennyRouteTracks.key(entries[index - 1].pod, entries[index].pod)] {
            return LennyStage(track: track)
        }
        return entries[index].stage
    }

    private var hasPath: Bool { entries.filter { $0.pod.coordinate != nil }.count >= 2 }

    /// The stops, one row each, settling in one after the other.
    private var stopsList: some View {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            row(entry, stage: stage(into: index), number: index + 1, isLast: index == entries.count - 1, date: flow.showsDates ? flow.date(forStop: index) : nil, nights: flow.nightsFor(index))
                .opacity(appeared || reduceMotion ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 14)
                .animation(.smooth(duration: 0.5).delay(0.08 * Double(index)), value: appeared)
        }
    }

    /// The route as a trace, big, what it adds up to, and which hut each dot is.
    private var routeMap: some View {
        VStack(alignment: .leading, spacing: 14) {
            LennyRoutePath(
                huts: entries.compactMap(\.pod.coordinate),
                legs: legs.map { pair in trails.tracks[LennyRouteTracks.key(pair.0, pair.1)]?.coordinates },
                isReady: trails.isDone,
                isLoop: isLoop,
                height: 340
            )
            .padding(.horizontal, 24)

            if let totals = routeTotals {
                T(totals)
                    .font(AppFont.regularLabel(12))
                    .foregroundColor(.homeSubtitle)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Button { onOpenPod(entry.pod) } label: {
                        HStack(spacing: 12) {
                            Text(verbatim: "\(index + 1)")
                                .font(AppFont.semiBoldLabel(10))
                                .foregroundColor(.homeBackground)
                                .frame(width: 20, height: 20)
                                .background(Color.homeText, in: Circle())
                            Text(entry.pod.name)
                                .font(AppFont.regularLabel(14))
                                .foregroundColor(.homeText)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
        }
        .padding(.bottom, 28)
    }

    // MARK: - Saving

    /// The saved plan with these huts, when this one was saved.
    private var savedPlan: SavedPlan? { savedPlans.plan(withPods: entries.map(\.pod.id)) }

    /// Keeps the plan to come back to (Profile > Plans), or takes it back out.
    private func toggleSaved() {
        if let existing = savedPlan {
            savedPlans.remove(existing)
            return
        }
        let request = flow.request
        savedPlans.add(SavedPlan(
            id: UUID(),
            title: planTitle ?? defaultTitle,
            savedAt: Date(),
            isLoop: isLoop,
            isRoute: entries.contains { $0.stage != nil },
            stops: entries.map { .init(name: $0.stopName, podId: $0.pod.id, detail: $0.detail, isPick: $0.isLennysPick) },
            guests: flow.guestsConfirmed ? flow.guests : request?.guests,
            startDate: flow.dateConfirmed ? flow.startDate : request?.startDate,
            nights: flow.nightsConfirmed ? flow.nights : request?.nights
        ))
    }

    private var defaultTitle: String {
        guard let first = entries.first, let last = entries.last, entries.count > 1 else { return entries.first?.pod.name ?? tr("Your plan") }
        return "\(first.stopName) → \(last.stopName)"
    }

    /// "Loop · 78 km · ~19 h" over the stages (and the way back, for a loop).
    private var routeTotals: String? {
        var stages = entries.indices.compactMap(stage(into:))
        guard !stages.isEmpty else { return nil }
        if isLoop, let first = entries.first?.pod, let last = entries.last?.pod {
            let back = trails.tracks[LennyRouteTracks.key(last, first)].map { LennyStage(track: $0) } ?? LennyStage.between(last, first)
            if let back { stages.append(back) }
        }
        let km = Int(stages.map(\.km).reduce(0, +).rounded())
        let hours = LennyStage.duration(stages.map(\.hours).reduce(0, +))
        return (isLoop ? tr("Loop") + "  ·  " : "") + "\(km) km  ·  ~\(hours)"
    }

    private var subtitle: String {
        let stops = entries.count
        return "\(stops) \(stops == 1 ? "stop" : "stops"), one hut each"
    }

    /// "Lake Braies  ·  Mon 2 Nov → Wed 4 Nov" once the dates are known.
    private func stopCaption(_ entry: Entry, from date: Date?, nights: Int) -> String {
        guard let date else { return entry.stopName }
        let format = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
        return "\(entry.stopName)  ·  \(date.formatted(format)) → \(flow.shifted(date, by: nights).formatted(format))"
    }

    /// A numbered dot on the line, then the stop, the pod and its photo.
    private func row(_ entry: Entry, stage: LennyStage?, number: Int, isLast: Bool, date: Date?, nights: Int) -> some View {
        Button { onOpenPod(entry.pod) } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    T("\(number)")
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
                    T(stopCaption(entry, from: date, nights: nights))
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
                                T(entry.detail)
                                    .font(AppFont.regularLabel(13))
                                    .foregroundColor(.homeSubtitle)
                                    .lineLimit(1)
                            }
                            if let stage {
                                T(stage.text)
                                    .font(AppFont.regularLabel(12))
                                    .foregroundColor(.homeSubtitle)
                                    .lineLimit(1)
                            }
                            if !entry.pod.isBookable {
                                T("Listed  ·  book through the hut")
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
                                    T("Lenny's pick")
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

import SwiftUI

/// "Check your plan" (Paper "LennyPlan" frames): one stop of the route at a
/// time, with the pods found around it in the folder grid's tiles. Tap a
/// tile to pick it for this stop (the first one until you pick); tap the
/// picked one again to look at it. The right pill moves to the next stop
/// and, on the last stop, opens the summary of the picked pods.
struct LennyPlanView: View {
    let stops: [LennySearchViewModel.JourneyStop]
    let photoURLs: [UUID: String]
    /// What Lenny understood, to prefill the booking (guests, dates, nights).
    var request: LennyRequest?
    /// The route comes back to its first hut.
    var isLoop = false
    /// What the plan is called when saved.
    var planTitle: String?
    /// Leaves the whole plan flow at once (back only steps back).
    var onExit: (() -> Void)?
    /// Back from the first stop leaves the plan.
    var onLeave: () -> Void
    var onOpenPod: (Pod) -> Void
    /// After the plan is booked: leaves Lenny for the reservations.
    var onFinish: () -> Void

    @State private var stopIndex = 0
    @State private var showsSummary = false
    @State private var asksToLeave = false
    /// The pod picked for each stop (by stop id).
    @State private var picks: [UUID: UUID] = [:]

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    private var stop: LennySearchViewModel.JourneyStop { stops[stopIndex] }
    private var isLastStop: Bool { stopIndex == stops.count - 1 }

    private var pickedPod: Pod? {
        stop.pods.first { $0.id == picks[stop.id] } ?? stop.pods.first
    }

    var body: some View {
        if showsSummary {
            LennySummaryView(
                entries: summaryEntries,
                photoURLs: photoURLs,
                onBack: { withAnimation(.easeInOut(duration: 0.3)) { showsSummary = false } },
                onOpenPod: onOpenPod,
                onViewReservations: onFinish,
                request: request,
                isLoop: isLoop,
                planTitle: planTitle,
                onExit: onExit
            )
            .transition(.opacity)
        } else {
            plan
        }
    }

    /// One entry per stop with the hut picked there; on a route across an
    /// area each says the day from the last hut.
    private var summaryEntries: [LennySummaryView.Entry] {
        var previous: Pod?
        var entries: [LennySummaryView.Entry] = []
        for stop in stops {
            guard let pod = stop.pods.first(where: { $0.id == picks[stop.id] }) ?? stop.pods.first else { continue }
            var details: [String] = []
            if let distance = stop.distanceText(for: pod) { details.append("\(distance) away") }
            if let beds = pod.bedsTotal { details.append("\(beds) \(beds == 1 ? "bed" : "beds")") }
            let asked = (request?.facilities ?? []).filter { (pod.facilities ?? []).contains($0) }
            if !asked.isEmpty { details.append(LennyFacilities.phrase(asked)) }
            entries.append(LennySummaryView.Entry(
                stopName: stop.name,
                pod: pod,
                detail: details.joined(separator: " · "),
                isLennysPick: pod.id == stop.pods.first?.id && stop.pickReason != nil,
                pickReason: pod.id == stop.pods.first?.id ? stop.pickReason : nil,
                stage: stop.isStage ? previous.flatMap { LennyStage.between($0, pod) } : nil
            ))
            previous = pod
        }
        return entries
    }

    private var plan: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    T("Check your plan")
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(-0.6)
                        .foregroundColor(.homeText)
                        .padding(.horizontal, 24)
                        .padding(.top, 25)

                    // Which stop these pods are around.
                    T("\(stop.name) · \(stopIndex + 1) of \(stops.count)")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)

                    pickCaption
                        .padding(.horizontal, 24)
                        .padding(.top, 10)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(stop.pods) { pod in
                            FolderPodTile(
                                pod: pod,
                                photoURL: photoURLs[pod.id],
                                isSelected: pod.id == pickedPod?.id,
                                onTap: { tap(pod) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    // Room to scroll the last row above the buttons.
                    .padding(.bottom, 152)
                }
            }
            .id(stop.id)

            // Fade into the ground behind the buttons.
            SectionFadeLayer(fade: .photos)

            HStack(spacing: 13) {
                if onExit != nil { CloseButton(size: 83) { asksToLeave = true } }
                DetailBackButton(action: back)
                DetailTextButton(title: isLastStop ? "See summary" : "Next stop: \(stops[stopIndex + 1].name)", action: next)
            }
            .padding(.horizontal, 24)
            // The cover respects the safe area: this puts the stack where every
            // control stack is (`DetailLayout.controlStackGap`).
            .padding(.bottom, DetailLayout.controlStackGap)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .lennyAsksToLeave($asksToLeave) { onExit?() }
    }

    /// Why the picked pod is there: Lenny's own pick says so and gives the
    /// reason; any other pod just says how far it is. One line, always the
    /// same height, so the grid below never jumps.
    private var pickCaption: some View {
        let pod = pickedPod
        let isPick = pod.map(isLennysPick) ?? false
        return HStack(spacing: 8) {
            if isPick {
                LennyPickBadge(size: 20)
            }
            Group {
                if isPick, let reason = stop.pickReason {
                    Text("\(T("Lenny's pick").font(AppFont.semiBoldLabel(13)).foregroundColor(.homeText))\(T("  ·  \(reason)").font(AppFont.regularLabel(13)).foregroundColor(.homeSubtitle))")
                } else if let pod, let distance = stop.distanceCaption(for: pod) {
                    Text(distance).font(AppFont.regularLabel(13)).foregroundColor(.homeSubtitle)
                } else {
                    T(" ").font(AppFont.regularLabel(13))
                }
            }
            .lineLimit(1)
        }
        .frame(height: 20, alignment: .leading)
        .id(pod?.id)
        .transition(.opacity)
        .animation(.easeInOut(duration: AppMotion.snappy), value: pod?.id)
    }

    private func isLennysPick(_ pod: Pod) -> Bool {
        pod.id == stop.pods.first?.id && stop.pickReason != nil
    }

    private func tap(_ pod: Pod) {
        if pod.id == pickedPod?.id {
            onOpenPod(pod)
        } else {
            withAnimation(.easeInOut(duration: AppMotion.snappy)) { picks[stop.id] = pod.id }
        }
    }

    private func back() {
        if stopIndex == 0 {
            onLeave()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { stopIndex -= 1 }
        }
    }

    private func next() {
        if isLastStop {
            withAnimation(.easeInOut(duration: 0.3)) { showsSummary = true }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { stopIndex += 1 }
        }
    }
}

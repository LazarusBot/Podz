import SwiftUI

/// "Check your plan" (Paper "LennyPlan" frames): one stop of the route at a
/// time, with the pods found around it in the folder grid's tiles. Tap a
/// tile to pick it for this stop (the first one until you pick); tap the
/// picked one again to look at it. The right pill moves to the next stop
/// and, on the last stop, opens the summary of the picked pods.
struct LennyPlanView: View {
    let stops: [LennySearchViewModel.JourneyStop]
    let photoURLs: [UUID: String]
    /// Back from the first stop leaves the plan.
    var onLeave: () -> Void
    var onOpenPod: (Pod) -> Void
    /// Leaves the plan altogether (the summary's Done).
    var onFinish: () -> Void

    @State private var stopIndex = 0
    @State private var showsSummary = false
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
                entries: stops.compactMap { stop in
                    (stop.pods.first { $0.id == picks[stop.id] } ?? stop.pods.first)
                        .map { LennySummaryView.Entry(stopName: stop.name, pod: $0) }
                },
                photoURLs: photoURLs,
                onBack: { withAnimation(.easeInOut(duration: 0.3)) { showsSummary = false } },
                onOpenPod: onOpenPod,
                onDone: onFinish
            )
            .transition(.opacity)
        } else {
            plan
        }
    }

    private var plan: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Check your plan")
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(-0.6)
                        .foregroundColor(.homeText)
                        .padding(.horizontal, 24)
                        .padding(.top, 25)

                    // Which stop these pods are around.
                    Text("\(stop.name) · \(stopIndex + 1) of \(stops.count)")
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
                                // Lenny's own pick carries the app's one color.
                                checkAccent: isLennysPick(pod) ? .lennyAccent : nil,
                                onTap: { tap(pod) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    // Room to scroll the last row above the buttons.
                    .padding(.bottom, 190)
                }
            }
            .id(stop.id)

            // Fade into the ground behind the buttons.
            BottomFade()

            HStack(spacing: 13) {
                DetailBackButton(action: back)
                DetailTextButton(title: isLastStop ? "See summary" : "Next stop: \(stops[stopIndex + 1].name)", action: next)
            }
            .padding(.horizontal, 24)
            // The cover respects the safe area, so 40 here is the 74 from
            // the bottom edge every control stack uses.
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
    }

    /// Why the picked pod is there: Lenny's own pick says so and gives the
    /// reason; any other pod just says how far it is. One line, always the
    /// same height, so the grid below never jumps.
    private var pickCaption: some View {
        let pod = pickedPod
        let isPick = pod.map(isLennysPick) ?? false
        return HStack(spacing: 8) {
            if isPick {
                Image("lenny")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.lennyAccent, in: Circle())
            }
            Group {
                if isPick, let reason = stop.pickReason {
                    Text("Lenny's pick").font(AppFont.semiBoldLabel(13)).foregroundColor(.lennyAccent)
                        + Text("  ·  \(reason)").font(AppFont.regularLabel(13)).foregroundColor(.homeSubtitle)
                } else if let pod, let distance = stop.distanceCaption(for: pod) {
                    Text(distance).font(AppFont.regularLabel(13)).foregroundColor(.homeSubtitle)
                } else {
                    Text(" ").font(AppFont.regularLabel(13))
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

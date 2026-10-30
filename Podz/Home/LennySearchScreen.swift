import SwiftUI

/// Lenny's itinerary search (Paper "LennySearch" frames), opened when a
/// route is submitted from the Home pill's Lenny mode.
///
/// "Lenny is searching…", the route in the inverted pill with Lenny's mark,
/// the steps ticking by, and the bottom pill row: back, and **View selected
/// pods**, which wakes up once every stop has been looked up and opens the
/// plan (`LennyPlanView`, Paper "LennyPlan").
struct LennySearchScreen: View {
    var onClose: () -> Void

    @ObservedObject private var lenny = LennySearchViewModel.shared
    @ObservedObject private var podsStore = PodsStore.shared
    @State private var showsPlan = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPod: Pod?
    @Namespace private var zoomNamespace

    /// Ready once the search is done and found something to plan with.
    private var canOpenPlan: Bool { lenny.phase == .results && !planStops.isEmpty }

    var body: some View {
        ZStack(alignment: .bottom) {
            if showsPlan, !planStops.isEmpty {
                LennyPlanView(
                    stops: planStops,
                    photoURLs: podsStore.primaryPhotoByPodId,
                    onLeave: { withAnimation(.easeInOut(duration: 0.3)) { showsPlan = false } },
                    onOpenPod: { selectedPod = $0 },
                    onFinish: onClose
                )
                .transition(.opacity)
            } else {
                // The texture is behind everything, edge to edge.
                DitherLoader()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(lenny.phase == .results ? 0 : 1)
                    .animation(.easeOut(duration: 0.6), value: lenny.phase)

                searching
                    .transition(.opacity)

                HStack(spacing: 13) {
                    DetailBackButton(action: onClose)
                    DetailTextButton(title: "View selected pods", isHighlighted: canOpenPlan) {
                        withAnimation(.easeInOut(duration: 0.3)) { showsPlan = true }
                    }
                    .disabled(!canOpenPlan)
                    .opacity(canOpenPlan ? 1 : 0.45)
                    .scaleEffect(canOpenPlan ? 1 : 0.97)
                    .animation(.bouncy(duration: 0.5), value: canOpenPlan)
                    .sensoryFeedback(.success, trigger: canOpenPlan) { _, ready in ready }
                }
                .padding(.horizontal, 24)
                // The cover respects the safe area, so 40 here is the 74 from
                // the bottom edge every control stack uses.
                .padding(.bottom, 40)
            }
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .interactiveDismissDisabled()
        .fullScreenCover(item: $selectedPod) { pod in
            MinimalPodDetailView(pod: pod, onBack: { selectedPod = nil })
                .navigationTransition(.zoom(sourceID: pod.id, in: zoomNamespace))
        }
    }

    // MARK: - Searching

    private var searching: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
                .font(AppFont.semiBoldLabel(30))
                .tracking(-0.6)
                .foregroundColor(.homeText)
                .padding(.horizontal, 24)
                .padding(.top, 25)

            routePill
                .padding(.horizontal, 24)
                .padding(.top, 20)

            // Positions from the Paper frame: the first dot sits 71 under the
            // pill, 45 from the left edge.
            LennyTimeline(steps: lenny.steps)
                .padding(.horizontal, 33)
                .padding(.top, 59)

            if let message = lenny.errorMessage {
                Text(message)
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.appBadgeRed)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// "Lenny is searching" with dots that come and go one by one. The hidden
    /// dots keep their room, so the title never reflows. Still, with Reduce
    /// Motion.
    private var title: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { context in
            let shownDots = reduceMotion ? 3 : Int(context.date.timeIntervalSinceReferenceDate / 0.45) % 4
            (0..<3).reduce(Text("Lenny is searching")) { text, index in
                text + Text(".").foregroundColor(index < shownDots ? .homeText : .clear)
            }
        }
    }

    /// The route as the Home pill leaves it in Lenny mode: inverted bar,
    /// Lenny's disc melted into it so only the eyes and mouth show.
    private var routePill: some View {
        HStack(spacing: 20) {
            Image("lenny")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(.homeBackground)
                .frame(width: 40, height: 40)
                // Lenny sways while it searches.
                .phaseAnimator(reduceMotion || lenny.phase == .results ? [0.0] : [-9.0, 9.0]) { view, angle in
                    view.rotationEffect(.degrees(angle))
                } animation: { _ in .easeInOut(duration: 0.7) }

            Text(lenny.itineraryText)
                .font(AppFont.regularLabel(16))
                .foregroundColor(.homeBackground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 9)
        .padding(.trailing, 28)
        .frame(height: 60)
        .background(Color.homeText, in: Capsule())
    }

    // MARK: - The plan

    /// The stops that found something; the plan walks through these.
    private var planStops: [LennySearchViewModel.JourneyStop] {
        lenny.journeyStops.filter { !$0.pods.isEmpty }
    }
}

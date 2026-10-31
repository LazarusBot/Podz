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
    /// What's typed in the route pill when it's open again after an error.
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool
    /// The user tapped the route to change it: the old route and Lenny's error
    /// are gone until a new search starts.
    @State private var isEditingRoute = false
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
                    onFinish: {
                        ProfileRouter.shared.showsReservationsRequested = true
                        onClose()
                    }
                )
                .transition(.opacity)
            } else {
                // The texture is behind everything, edge to edge.
                PlanetLoader()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(lenny.phase == .results ? 0 : 1)
                    .animation(.easeOut(duration: 0.6), value: lenny.phase)

                searching
                    .transition(.opacity)

                // Lenny's answer to the route: typing, then the result.
                if !isEditingRoute {
                    LennyReply(message: replyMessage, mood: mood)
                        .padding(.horizontal, 24)
                        // Just above the pill row (83 high, 40 + safe area up).
                        .padding(.bottom, 40 + 83 + 20)
                        .transition(.opacity)
                }

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
        .animation(.smooth(duration: 0.3), value: isEditingRoute)
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
                .animation(.smooth(duration: 0.45), value: lenny.phase)
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
            LennyTimeline(steps: lenny.steps, isStopped: lenny.phase == .results)
                .padding(.horizontal, 33)
                .padding(.top, 59)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// "Lenny is searching" with dots that come and go one by one (the hidden
    /// dots keep their room, so the title never reflows; still, with Reduce
    /// Motion). When the search is over it becomes "3 pods found".
    @ViewBuilder
    private var title: some View {
        if lenny.phase == .results {
            Text(foundTitle)
                .transition(.blurReplace)
        } else {
            TimelineView(.periodic(from: .now, by: 0.45)) { context in
                let shownDots = reduceMotion ? 3 : Int(context.date.timeIntervalSinceReferenceDate / 0.45) % 4
                (0..<3).reduce(Text("Lenny is searching")) { text, index in
                    text + Text(".").foregroundColor(index < shownDots ? .homeText : .clear)
                }
            }
            .transition(.blurReplace)
        }
    }

    /// Different pods only: one can be near two stops.
    private var foundCount: Int {
        Set(planStops.flatMap { $0.pods.map(\.id) }).count
    }

    private var foundTitle: String {
        switch foundCount {
        case 0: return "No pods found"
        case 1: return "1 pod found"
        default: return "\(foundCount) pods found"
        }
    }

    /// Whether the search came back empty-handed: Lenny says why, in its own
    /// words, and its face says sorry.
    private var failed: Bool { lenny.phase == .results && (lenny.errorMessage != nil || foundCount == 0) }

    private var mood: LennyMood {
        guard lenny.phase == .results else { return .working }
        if isEditingRoute { return .idle }
        return failed ? .sorry : .happy
    }

    /// What Lenny says when it's done; `nil` while it's still working.
    private var replyMessage: String? {
        guard lenny.phase == .results else { return nil }
        if let error = lenny.errorMessage { return error }
        switch foundCount {
        case 0: return "I couldn't find any pods on that route."
        case 1: return "I found 1 pod along your route. Want to take a look?"
        default: return "I found \(foundCount) pods along your route. Want to take a look?"
        }
    }

    /// The route as the Home pill leaves it in Lenny mode: inverted bar,
    /// Lenny's disc melted into it so only the eyes and mouth show.
    private var routePill: some View {
        HStack(spacing: 20) {
            LennyMark(mood: mood)
                .frame(width: 20, height: 20)
                .foregroundColor(.homeBackground)
                .frame(width: 40, height: 40)

            if failed {
                // After an error the route is yours to change: tap, edit,
                // Search.
                TextField(
                    "",
                    text: $draft,
                    prompt: Text("Chamonix to Zermatt in 5 days").foregroundColor(.homeSubtitleOnInverse)
                )
                .font(AppFont.regularLabel(16))
                .foregroundColor(.homeBackground)
                .tint(.homeBackground)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($fieldFocused)
                .onSubmit(retry)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(lenny.itineraryText)
                    .font(AppFont.regularLabel(16))
                    .foregroundColor(.homeBackground)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, 28)
        .frame(height: 60)
        .background(Color.homeText, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            guard failed else { return }
            fieldFocused = true
        }
        // The field takes the tap itself, so this is what starts editing:
        // getting focus clears the old route and Lenny's error, leaving a
        // clean field to type in.
        .onChange(of: fieldFocused) { _, focused in
            guard focused, failed, !isEditingRoute else { return }
            isEditingRoute = true
            draft = ""
        }
        // The route is in the field when a search fails.
        .onChange(of: failed) { _, isFailed in
            if isFailed {
                draft = lenny.itineraryText
                isEditingRoute = false
            }
        }
    }

    /// Searches again with the edited route.
    private func retry() {
        let route = draft.trimmingCharacters(in: .whitespaces)
        guard !route.isEmpty else { return }
        fieldFocused = false
        showsPlan = false
        isEditingRoute = false
        lenny.start(route)
    }

    // MARK: - The plan

    /// The stops that found something; the plan walks through these.
    private var planStops: [LennySearchViewModel.JourneyStop] {
        lenny.journeyStops.filter { !$0.pods.isEmpty }
    }
}

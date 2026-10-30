import SwiftUI

/// Lenny's itinerary search (Paper "LennySearch" frames), opened when a
/// route is submitted from the Home pill's Lenny mode.
///
/// "Lenny is searching…", the route in the inverted pill with Lenny's mark,
/// the steps ticking by, and the bottom pill row: back, and **View selected
/// pods**, which wakes up once the search has results.
/// The results themselves (`LennyPlan` frames) still use the old list.
struct LennySearchScreen: View {
    var onClose: () -> Void

    @ObservedObject private var lenny = LennySearchViewModel.shared
    @ObservedObject private var podsStore = PodsStore.shared
    @State private var showsResults = false
    @State private var selectedPod: Pod?
    @Namespace private var zoomNamespace

    private var hasResults: Bool { lenny.phase == .results }

    var body: some View {
        ZStack(alignment: .bottom) {
            if showsResults {
                resultsList
                    .transition(.opacity)
            } else {
                searching
                    .transition(.opacity)
            }

            HStack(spacing: 13) {
                DetailBackButton(action: back)

                if !showsResults {
                    DetailTextButton(title: "View selected pods") {
                        withAnimation(.easeInOut(duration: 0.3)) { showsResults = true }
                    }
                    .disabled(!hasResults)
                    .opacity(hasResults ? 1 : 0.45)
                }
            }
            .padding(.horizontal, 24)
            // The cover respects the safe area, so 40 here is the 74 from
            // the bottom edge every control stack uses.
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        // The results list still uses fixed black-on-white colors.
        .preferredColorScheme(showsResults ? .light : nil)
        .interactiveDismissDisabled()
        .fullScreenCover(item: $selectedPod) { pod in
            MinimalPodDetailView(pod: pod, onBack: { selectedPod = nil })
                .navigationTransition(.zoom(sourceID: pod.id, in: zoomNamespace))
                .preferredColorScheme(.light)
        }
    }

    /// Back from the results goes to the steps; back from the steps leaves.
    private func back() {
        if showsResults {
            withAnimation(.easeInOut(duration: 0.3)) { showsResults = false }
        } else {
            onClose()
        }
    }

    // MARK: - Searching

    private var searching: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lenny is searching…")
                .font(AppFont.semiBoldLabel(30))
                .tracking(-0.6)
                .foregroundColor(.homeText)
                .padding(.horizontal, 24)
                .padding(.top, 25)

            routePill
                .padding(.horizontal, 24)
                .padding(.top, 20)

            LennyTimeline(steps: lenny.steps)
                .padding(.horizontal, 36)
                .padding(.top, 52)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

            Text(lenny.itineraryText)
                .font(AppFont.regularLabel(14))
                .foregroundColor(.homeBackground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 9)
        .padding(.trailing, 28)
        .frame(height: 60)
        .background(Color.homeText, in: Capsule())
    }

    // MARK: - Results (old list, until the LennyPlan frames land)

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                LennyJourneyProgress(stops: lenny.journeyStops)
                    .padding(.top, 24)

                VStack(spacing: 30) {
                    ForEach(lenny.matchingPods) { pod in
                        LennyResultCard(
                            pod: pod,
                            photoURL: podsStore.primaryPhotoByPodId[pod.id],
                            isSelected: lenny.selectedPodIDs.contains(pod.id),
                            onToggleSelect: { lenny.toggleSelection(for: pod) },
                            onTapCard: { selectedPod = pod },
                            zoomNamespace: zoomNamespace
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

                Color.clear.frame(height: 190)
            }
        }
    }
}

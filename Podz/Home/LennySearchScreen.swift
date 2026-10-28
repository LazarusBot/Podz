import SwiftUI

/// Lenny's itinerary search, opened from the Home pill's round button.
/// Same phases and components the old Home used — describe a route, watch
/// the steps tick by, pick from the matching pods — just on its own screen
/// instead of inside Home's search pill.
struct LennySearchScreen: View {
    @ObservedObject private var lenny = LennySearchViewModel.shared
    @ObservedObject private var podsStore = PodsStore.shared
    @State private var selectedPod: Pod?
    @Namespace private var zoomNamespace
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { lenny.cancel() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if lenny.phase == .editing {
                field
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }

            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
        // The Lenny components still use fixed black-on-white colors.
        .preferredColorScheme(.light)
        .onAppear { fieldFocused = lenny.phase == .editing }
        .onChange(of: lenny.phase) { _, phase in
            fieldFocused = phase == .editing
        }
        .fullScreenCover(item: $selectedPod) { pod in
            PodDetailView(pod: pod, onBack: { selectedPod = nil })
                .navigationTransition(.zoom(sourceID: pod.id, in: zoomNamespace))
                .preferredColorScheme(.light)
        }
    }

    private var field: some View {
        TextField(
            "",
            text: $lenny.itineraryText,
            prompt: Text("Chamonix to Zermatt in 5 days").foregroundColor(.black.opacity(0.35)),
            axis: .vertical
        )
        .font(AppFont.regularLabel(16))
        .foregroundColor(.black)
        .lineLimit(1...4)
        .focused($fieldFocused)
        .submitLabel(.search)
        .onSubmit { Task { await lenny.submit() } }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color(white: 0xF1 / 255), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch lenny.phase {
        case .idle:
            EmptyView()
        case .editing:
            VStack(spacing: 32) {
                LennyWalkingAvatar()
                Text(lenny.errorMessage ?? "Describe your hike and Lenny will find pods along the way.")
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(lenny.errorMessage == nil ? .appTextMuted : .red)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.horizontal, 40)
        case .searching:
            LennySearchSteps(steps: lenny.steps)
        case .results:
            LennyJourneyProgress(stops: lenny.journeyStops)

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
        }
    }
}

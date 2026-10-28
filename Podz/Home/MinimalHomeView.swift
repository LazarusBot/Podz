import SwiftUI

/// The minimalist Home (Paper "Home" frames): a big question, one search
/// pill, and a row of large pod cards on a pure black / white ground.
/// Lenny's itinerary search lives behind the pill's round button
/// (`LennySearchScreen`).
struct MinimalHomeView: View {
    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var lenny = LennySearchViewModel.shared
    @StateObject private var homeSearch = HomeSearchState.shared
    @StateObject private var scrollState = ScrollTrackingState.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared

    @State private var query = ""
    @State private var selectedPod: Pod?
    @State private var showAllPods = false
    @Namespace private var zoomNamespace

    private var visiblePods: [Pod] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return podsStore.pods }
        return podsStore.pods.filter { pod in
            pod.name.localizedCaseInsensitiveContains(query)
                || pod.country.localizedCaseInsensitiveContains(query)
                || (pod.region?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                title
                searchPill
                sectionHeader
                feed.padding(.top, 16)

                // Room so the cards' captions clear the floating tab bar.
                Color.clear.frame(height: 110)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
            scrollState.updateOffset(offset)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .fullScreenCover(isPresented: lennyPresented) { LennySearchScreen() }
        .sheet(isPresented: $showAllPods) {
            HomeAllPodsSheet(pods: podsStore.pods, photoURLs: podsStore.primaryPhotoByPodId)
        }
        // Zoom cover, same as the old Home: the tapped card's photo grows
        // into the detail and shrinks back on close. A pod with no card
        // here (a deep link) falls back to the default cover animation.
        .fullScreenCover(item: $selectedPod) { pod in
            PodDetailView(pod: pod, onBack: { selectedPod = nil })
                .navigationTransition(.zoom(sourceID: pod.id, in: zoomNamespace))
                .preferredColorScheme(.light)
        }
        .task { await podsStore.fetchPods() }
        .task { await likesStore.fetchAll() }
        .onChange(of: homeSearch.feedReselected) { _, _ in
            // Home tapped again while already on Home: back to the root.
            query = ""
            selectedPod = nil
        }
        // Both triggers matter: a link tapped while the app is running
        // fires the pendingPodId change first; a cold launch races
        // fetchPods() against .onOpenURL, so pods finishing the fetch is
        // what resolves it there.
        .onChange(of: deepLinkRouter.pendingPodId) { _, _ in resolveDeepLink() }
        .onChange(of: podsStore.pods) { _, _ in resolveDeepLink() }
        .onAppear {
            resolveDeepLink()
            // ScrollTrackingState is shared by every scrollable tab —
            // without this a stale offset from another tab could flash the
            // tab bar's shrink for a beat.
            scrollState.reset()
        }
    }

    private var title: some View {
        Text("Where to tonight?")
            .font(AppFont.semiBoldLabel(30))
            .tracking(-0.6)
            .foregroundColor(.homeText)
            .padding(.horizontal, 24)
            .padding(.top, 25)
    }

    private var searchPill: some View {
        HomeSearchPill(text: $query, onLenny: { lenny.activate() })
            .padding(.horizontal, 24)
            .padding(.top, 20)
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Available tonight")
                .font(AppFont.semiBoldLabel(16))
                .foregroundColor(.homeText)
            Spacer()
            Button("See all") { showAllPods = true }
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
                .disabled(podsStore.pods.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    /// Lenny's screen is open for as long as its search isn't idle.
    private var lennyPresented: Binding<Bool> {
        Binding(
            get: { lenny.phase != .idle },
            set: { if !$0 { lenny.forceReset() } }
        )
    }

    @ViewBuilder
    private var feed: some View {
        if podsStore.isLoading && podsStore.pods.isEmpty {
            loading
        } else if visiblePods.isEmpty {
            Text(query.isEmpty ? "No pods available yet." : "No pods match “\(query)”.")
                .font(AppFont.regularLabel(14))
                .foregroundColor(.homeSubtitle)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(visiblePods) { pod in
                        HomePodCard(
                            pod: pod,
                            photoURL: podsStore.primaryPhotoByPodId[pod.id],
                            zoomNamespace: zoomNamespace,
                            onTap: { selectedPod = pod }
                        )
                        .containerRelativeFrame(.horizontal) { width, _ in width - 97 }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 24, for: .scrollContent)
        }
    }

    private var loading: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonShape(cornerRadius: 36)
                        .aspectRatio(296.0 / 340.0, contentMode: .fit)
                    SkeletonShape(cornerRadius: AppRadius.r4)
                        .frame(width: 140, height: 16)
                        .padding(.leading, 5)
                }
                .containerRelativeFrame(.horizontal) { width, _ in width - 97 }
            }
        }
        .padding(.leading, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    /// Opens `PodDetailView` for whatever pod `DeepLinkRouter` is holding,
    /// once it's actually in `podsStore.pods`.
    private func resolveDeepLink() {
        guard let podId = deepLinkRouter.pendingPodId else { return }
        guard let pod = podsStore.pods.first(where: { $0.id == podId }) else { return }
        selectedPod = pod
        deepLinkRouter.pendingPodId = nil
    }
}

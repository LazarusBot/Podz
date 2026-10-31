import SwiftUI

/// The minimalist Home (Paper "Home" frames): a big question, one search
/// pill, and a row of large pod cards on a pure black / white ground.
struct MinimalHomeView: View {
    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var homeSearch = HomeSearchState.shared
    @StateObject private var scrollState = ScrollTrackingState.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared

    @State private var query = ""
    /// What's typed while the pill is in Lenny mode — kept apart from
    /// `query` so a route sentence never filters the cards.
    @State private var lennyQuery = ""
    @StateObject private var router = TabRouter.shared
    @State private var isLennyMode = false
    @FocusState private var searchFocused: Bool
    @State private var selectedPod: Pod?
    @State private var showAllPods = false
    @State private var showLenny = false
    @Namespace private var zoomNamespace

    /// One card plus a 73pt peek of the next (24 margin + 12 gap + 61 peek).
    /// A fixed width from the screen, not `containerRelativeFrame`: inside a
    /// horizontal scroll view nested in this vertical one it resolved to an
    /// infinite width and crashed the layer tree.
    private static var cardWidth: CGFloat { UIScreen.main.bounds.width - 97 }

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
        // Tap outside the field to close the keyboard — the cards and
        // buttons handle their own taps first.
        .onTapGesture { searchFocused = false }
        // Leaving the field also leaves Lenny mode: the mark rolls back.
        .onChange(of: searchFocused) { _, focused in
            if !focused { isLennyMode = false }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
            scrollState.updateOffset(offset)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .sheet(isPresented: $showAllPods) {
            HomeAllPodsSheet(pods: podsStore.pods, photoURLs: podsStore.primaryPhotoByPodId)
        }
        // Zoom cover, same as the old Home: the tapped card's photo grows
        // into the detail and shrinks back on close. A pod with no card
        // here (a deep link) falls back to the default cover animation.
        .fullScreenCover(item: $selectedPod) { pod in
            MinimalPodDetailView(pod: pod, onBack: { selectedPod = nil })
                .navigationTransition(.zoom(sourceID: pod.id, in: zoomNamespace))
        }
        // A route sent to Lenny opens its search screen.
        .fullScreenCover(isPresented: $showLenny) {
            LennySearchScreen(onClose: closeLenny)
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
        .onChange(of: router.lennyRequested) { _, requested in
            if requested { openLenny() }
        }
        .onAppear {
            if router.lennyRequested { openLenny() }
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
        HomeSearchPill(
            text: isLennyMode ? $lennyQuery : $query,
            isLennyMode: $isLennyMode,
            isFocused: $searchFocused,
            onSubmit: submitSearch
        )
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

    @ViewBuilder
    private var feed: some View {
        if podsStore.isLoading && podsStore.pods.isEmpty {
            loading
        } else if visiblePods.isEmpty {
            VStack(spacing: 6) {
                Text(query.isEmpty ? "No pods available yet." : "No pods match “\(query)”.")
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.homeSubtitle)

                // The search found nothing: the moment to offer Lenny, with
                // what was typed.
                if !query.isEmpty {
                    Button(action: handToLenny) {
                        HStack(spacing: 5) {
                            Text("Ask Lenny to find it")
                                .font(AppFont.regularLabel(13))
                                .foregroundColor(.homeSubtitle)
                                .underline(color: Color.homeSubtitle.opacity(0.5))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.homeSubtitle)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
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
                        .frame(width: Self.cardWidth)
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
                .frame(width: Self.cardWidth)
            }
        }
        .padding(.leading, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    /// Search key: in Lenny mode the route goes to Lenny; in classic mode the
    /// cards are already filtered, so it just closes the keyboard.
    private func submitSearch() {
        searchFocused = false
        let route = lennyQuery.trimmingCharacters(in: .whitespaces)
        guard isLennyMode, !route.isEmpty else { return }
        LennySearchViewModel.shared.start(route)
        showLenny = true
    }

    /// The search found nothing: what was typed becomes the route in Lenny's
    /// field, ready to edit and send.
    private func handToLenny() {
        lennyQuery = query
        query = ""
        isLennyMode = true
        searchFocused = true
    }

    /// Something asked for Lenny (the empty Reservations page): the pill rolls
    /// to Lenny mode and the keyboard opens.
    private func openLenny() {
        router.lennyRequested = false
        isLennyMode = true
        Task {
            // Let the tab finish appearing before asking for the keyboard.
            try? await Task.sleep(nanoseconds: 350_000_000)
            searchFocused = true
        }
    }

    private func closeLenny() {
        showLenny = false
        lennyQuery = ""
        LennySearchViewModel.shared.forceReset()
    }

    /// Opens `MinimalPodDetailView` for whatever pod `DeepLinkRouter` is holding,
    /// once it's actually in `podsStore.pods`.
    private func resolveDeepLink() {
        guard let podId = deepLinkRouter.pendingPodId else { return }
        guard let pod = podsStore.pods.first(where: { $0.id == podId }) else { return }
        selectedPod = pod
        deepLinkRouter.pendingPodId = nil
    }
}

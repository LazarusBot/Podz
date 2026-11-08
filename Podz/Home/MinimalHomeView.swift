import SwiftUI

/// The minimalist Home (Paper "Home" frames): a big question, one search
/// pill, and a row of large pod cards on a pure black / white ground.
struct MinimalHomeView: View {
    /// Home stays mounted under the other tabs; false while another is shown.
    var isActive = true
    /// Where Home's own scroll is (kept while it's hidden).
    @State private var homeOffset: CGFloat = 0
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
    /// The shelf whose "See all" is open.
    @State private var seeAll: HomeSection?
    /// Which card was tapped, to zoom from it (a pod can be on several shelves).
    @State private var selectedZoomID: AnyHashable?
    @State private var showLenny = false
    @Namespace private var zoomNamespace

    /// One card plus a 73pt peek of the next (24 margin + 12 gap + 61 peek).
    /// A fixed width from the screen, not `containerRelativeFrame`: inside a
    /// horizontal scroll view nested in this vertical one it resolved to an
    /// infinite width and crashed the layer tree.
    private static var cardWidth: CGFloat { ScreenInsets.screenWidth - 97 }

    /// What the feed shows. With thousands of listed huts, these are worked out
    /// when the pods or the query change, not on every redraw (scrolling
    /// redraws many times a second).
    @State private var tonightPods: [Pod] = []
    @State private var searchResults: [Pod] = []
    @State private var discovery: [HomeSection] = []

    private var visiblePods: [Pod] {
        query.trimmingCharacters(in: .whitespaces).isEmpty ? tonightPods : searchResults
    }

    /// "Available tonight" is what can be booked in the app; the listed huts
    /// are found by searching, the shelves and Lenny.
    private func rebuildShelves() {
        tonightPods = podsStore.pods.filter(\.isBookable)
        // The shelves lead with the huts that are well documented, and the
        // hand-picked ones get a shelf of their own.
        let photoIDs = photoIDs
        let worthy = podsStore.pods.filter { PodQuality.isShelfWorthy($0, hasPhoto: photoIDs.contains($0.id)) }
        var sections = HomeSection.discovery(from: worthy)
        let picked = PodQuality.ranked(podsStore.pods.filter { $0.featured == true }, photoIDs: photoIDs)
        if picked.count >= 3 {
            sections.insert(HomeSection(id: "featured", title: "Hand-picked", pods: Array(picked.prefix(10)), allPods: picked), at: 0)
        }
        discovery = sections
        updateSearch()
    }

    /// The pods that have a photo.
    private var photoIDs: Set<UUID> {
        Set(podsStore.primaryPhotoByPodId.filter { !$0.value.isEmpty }.keys)
    }

    /// Partner huts first, then the best documented, then by name.
    private func updateSearch() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            searchResults = []
            return
        }
        let search = PodSearchQuery(text)
        let found = podsStore.pods.filter(search.matches)
        searchResults = PodQuality.ranked(found, photoIDs: photoIDs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                title
                searchPill
                sectionHeader(title: "Available tonight", pods: tonightPods, id: "tonight")
                feed.padding(.top, 16)

                // More ways in than the search bar: shelves by what you liked,
                // altitude, groups, region and kind. Searching hides them.
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ForEach(discoverySections) { section in
                        sectionHeader(title: section.title, pods: section.pods, id: section.id, all: section)
                        shelf(section)
                            .padding(.top, 16)
                    }
                }

                // Room so the cards' captions clear the floating tab bar.
                Color.clear.frame(height: 110)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        // Tap outside the field to close the keyboard. A simultaneous gesture,
        // so it runs next to the cards' own taps instead of competing with
        // them (a plain onTapGesture here made the cards' taps flaky).
        .simultaneousGesture(TapGesture().onEnded { searchFocused = false })
        // Leaving the field also leaves Lenny mode: the mark rolls back.
        .onChange(of: searchFocused) { _, focused in
            if !focused { isLennyMode = false }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
            homeOffset = offset
            if isActive { scrollState.updateOffset(offset) }
        }
        // Home stays alive under the other tabs (so coming back is instant, with
        // the scroll where it was): the shared scroll tracker picks up from
        // Home's own offset, not whatever the other tab left in it.
        .onChange(of: isActive) { _, active in
            guard active else { return }
            scrollState.reset(offset: homeOffset)
            resolveDeepLink()
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .sheet(item: $seeAll) { section in
            HomeAllPodsSheet(
                title: section.title,
                pods: section.allPods ?? section.pods,
                photoURLs: podsStore.primaryPhotoByPodId,
                initialSort: section.seeAllSort
            )
        }
        // Zoom cover, same as the old Home: the tapped card's photo grows
        // into the detail and shrinks back on close. A pod with no card
        // here (a deep link) falls back to the default cover animation.
        .fullScreenCover(item: $selectedPod) { pod in
            MinimalPodDetailView(pod: pod, onBack: { selectedPod = nil })
                .navigationTransition(.zoom(sourceID: selectedZoomID ?? AnyHashable(pod.id), in: zoomNamespace))
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
        .onChange(of: podsStore.pods) { _, _ in
            rebuildShelves()
            resolveDeepLink()
            // Fold the names now, so the first letters typed aren't slow.
            let pods = podsStore.pods
            Task.detached(priority: .utility) { PodSearchIndex.shared.prepare(pods) }
        }
        .onChange(of: podsStore.primaryPhotoByPodId) { _, _ in rebuildShelves() }
        .onChange(of: query) { _, _ in updateSearch() }
        .onChange(of: router.lennyRequested) { _, requested in
            if requested { openLenny() }
        }
        .onAppear {
            rebuildShelves()
            if router.lennyRequested { openLenny() }
            resolveDeepLink()
            // ScrollTrackingState is shared by every scrollable tab —
            // without this a stale offset from another tab could flash the
            // tab bar's shrink for a beat.
            scrollState.reset()
        }
    }

    private var title: some View {
        T("Where to tonight?")
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

    /// A shelf's title and its "See all".
    private func sectionHeader(title: String, pods: [Pod], id: String, all: HomeSection? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            T(title)
                .font(AppFont.semiBoldLabel(16))
                .foregroundColor(.homeText)
            Spacer()
            Button { seeAll = all ?? HomeSection(id: id, title: title, pods: pods) } label: {
                T("See all")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .captionTapArea(outset: 14)
            }
            .buttonStyle(.plain)
            .disabled(pods.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    /// The shelves under "Available tonight".
    private var discoverySections: [HomeSection] { discovery }

    /// A shelf in its own layout: carousel, tall cards or a mosaic.
    @ViewBuilder
    private func shelf(_ section: HomeSection) -> some View {
        switch section.layout {
        case .hero:
            cardsRow(section.pods, idPrefix: section.id, subtitle: section.subtitle)
        case .tall:
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(section.pods) { pod in
                        let zoomID = AnyHashable("\(section.id)-\(pod.id)")
                        HomeTallCard(
                            pod: pod,
                            photoURL: podsStore.primaryPhotoByPodId[pod.id],
                            zoomNamespace: zoomNamespace,
                            zoomID: zoomID,
                            onTap: {
                                selectedZoomID = zoomID
                                selectedPod = pod
                            }
                        )
                    }
                }
            }
            .contentMargins(.horizontal, 24, for: .scrollContent)
        case .mosaic:
            HomeMosaic(
                pods: section.pods,
                photoURLs: podsStore.primaryPhotoByPodId,
                zoomNamespace: zoomNamespace,
                zoomIDPrefix: section.id
            ) { pod, zoomID in
                selectedZoomID = zoomID
                selectedPod = pod
            }
        }
    }

    /// One row of big cards, scrolling sideways with the next one peeking.
    private func cardsRow(_ pods: [Pod], idPrefix: String, subtitle: ((Pod) -> String)?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(pods) { pod in
                    let zoomID = AnyHashable("\(idPrefix)-\(pod.id)")
                    HomePodCard(
                        pod: pod,
                        photoURL: podsStore.primaryPhotoByPodId[pod.id],
                        zoomNamespace: zoomNamespace,
                        zoomID: zoomID,
                        subtitleOverride: subtitle?(pod),
                        onTap: {
                            selectedZoomID = zoomID
                            selectedPod = pod
                        }
                    )
                    .frame(width: Self.cardWidth)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 24, for: .scrollContent)
    }

    @ViewBuilder
    private var feed: some View {
        if podsStore.isLoading && podsStore.pods.isEmpty {
            // Nothing to show yet, and nothing to say: the cards arrive in place.
            Color.clear.frame(height: 1)
        } else if visiblePods.isEmpty {
            VStack(spacing: 6) {
                T(query.isEmpty ? "No huts available yet." : "No huts match “\(query)”.")
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.homeSubtitle)

                // The search found nothing: the moment to offer Lenny, with
                // what was typed.
                if !query.isEmpty {
                    Button(action: handToLenny) {
                        HStack(spacing: 5) {
                            T("Ask Lenny to find it")
                                .font(AppFont.regularLabel(13))
                                .foregroundColor(.homeSubtitle)
                                .underline(color: Color.homeSubtitle.opacity(0.5))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.homeSubtitle)
                        }
                        .padding(.vertical, 8)
                        .captionTapArea()
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            cardsRow(visiblePods, idPrefix: "tonight", subtitle: nil)
        }
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
        selectedZoomID = nil
        selectedPod = pod
        deepLinkRouter.pendingPodId = nil
    }
}

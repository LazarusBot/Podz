import SwiftUI

/// Reports the "Friends' posts" section's real available width — same
/// background-GeometryReader-plus-preference trick as PodCard's
/// `SectionWidthPreferenceKey`.
private struct PostsFeedWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = UIScreen.main.bounds.width
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Which of Home's two feeds is showing — pod browsing (with search/
/// filters/Lenny) or friends' posts. Previously both lived in one
/// continuous scroll, posts always below every pod section; this splits
/// them so each is reachable without scrolling past the other.
private enum HomeFeedTab: CaseIterable {
    case pods, friends

    var title: String {
        switch self {
        case .pods: return "Pods"
        case .friends: return "Friends"
        }
    }
}

/// node 3779:2045 — "Home"
struct HomeView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var postsStore = PostsStore.shared
    @StateObject private var lenny = LennySearchViewModel.shared
    @StateObject private var homeSearch = HomeSearchState.shared
    @StateObject private var filters = HomeFiltersState.shared
    @StateObject private var scrollState = ScrollTrackingState.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared
    @State private var selectedPod: Pod?
    @State private var locationSearch = ""
    @State private var showLennyCoachmark = false
    @State private var showPostComposer = false
    @State private var feedTab: HomeFeedTab = .pods
    /// Transient "+1" on the toggle's "Friends" label after posting —
    /// same self-clearing confirmation LikesStore's `flashRecentLikeBadge`
    /// gives the bottom tab bar's Likes icon, not a running unread count.
    @State private var showRecentPostBadge = false
    @State private var recentPostBadgeTask: Task<Void, Never>?
    @State private var postsFeedAvailableWidth: CGFloat = UIScreen.main.bounds.width
    /// Set by tapping anywhere on a `PostCard` in the friends feed —
    /// pushes `PostDetailView` for that post, same manual @State push/pop
    /// pattern `selectedPod` already uses for `PodDetailView`.
    @State private var selectedPost: Post?
    /// Persisted so the coachmark only ever shows once, not once per
    /// session — not routing-related (see AuthManager's justRegistered
    /// note on the old hasSeenOnboarding bug), so plain @AppStorage is
    /// fine here.
    @AppStorage("podz.hasSeenLennyCoachmark") private var hasSeenLennyCoachmark = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if let pod = selectedPod {
                PodDetailView(pod: pod, onBack: { selectedPod = nil })
            } else if let post = selectedPost {
                PostDetailView(
                    post: post,
                    onBack: { selectedPost = nil },
                    onTapPod: {
                        if let pod = podsStore.pods.first(where: { $0.id == post.podId }) {
                            selectedPost = nil
                            selectedPod = pod
                        }
                    }
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        HomeHeader(
                            greeting: "Good morning,",
                            username: auth.profile?.username ?? "guest",
                            avatarImageName: auth.profile?.avatarURL
                        )

                        HomeSearchRow(searchText: $locationSearch)

                        if lenny.phase == .searching {
                            LennySearchSteps(steps: lenny.steps)
                        }

                        if let error = lenny.errorMessage {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }

                        if lenny.phase == .results {
                            LennyJourneyProgress(stops: lenny.journeyStops)

                            VStack(spacing: 30) {
                                ForEach(lenny.matchingPods) { pod in
                                    LennyResultCard(
                                        pod: pod,
                                        photoURL: podsStore.primaryPhotoByPodId[pod.id],
                                        isSelected: lenny.selectedPodIDs.contains(pod.id),
                                        onToggleSelect: { lenny.toggleSelection(for: pod) },
                                        onTapCard: { selectedPod = pod }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                        } else if lenny.phase == .editing && lenny.itineraryText.isEmpty {
                            awaitingLennyQueryState
                        } else if lenny.phase == .idle {
                            let query = locationSearch.trimmingCharacters(in: .whitespaces)
                            // Opening the search field clears the feed until
                            // a query is actually typed — showing every pod
                            // while the field sits empty and focused reads
                            // as "search does nothing".
                            let isAwaitingQuery = homeSearch.isExpanded && query.isEmpty
                            let nonEmptySections = isAwaitingQuery ? [] : podsStore.countries.compactMap { country -> (String, [Pod])? in
                                let pods = podsStore.pods(inCountry: country).filter { pod in
                                    let matchesQuery = query.isEmpty
                                        || country.localizedCaseInsensitiveContains(query)
                                        || (pod.region?.localizedCaseInsensitiveContains(query) ?? false)
                                    // Wifi/Pets/Check-in/Checkout stay display-only until `pods`
                                    // has data to filter them on — see HomeFiltersState.
                                    let matchesHikers = filters.hikers == 0 || (pod.bedsTotal ?? 0) >= filters.hikers
                                    return matchesQuery && matchesHikers
                                }
                                return pods.isEmpty ? nil : (country, pods)
                            }

                            if isAwaitingQuery {
                                awaitingQueryState
                            } else {
                                // Only alongside the pod-browsing content,
                                // not while the search pill's own full-
                                // screen "awaiting a query" prompt is
                                // showing.
                                HomeFeedToggle(selection: $feedTab, showFriendsBadge: showRecentPostBadge)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 4)
                                    .padding(.bottom, 12)

                                if feedTab == .pods {
                                    if podsStore.isLoading && podsStore.pods.isEmpty {
                                        loadingState
                                    } else if nonEmptySections.isEmpty {
                                        emptyState
                                    } else {
                                        ForEach(nonEmptySections, id: \.0) { country, pods in
                                            PodSection(
                                                title: "Preferred pods — \(country)",
                                                pods: pods,
                                                photoURLs: podsStore.primaryPhotoByPodId,
                                                showLikeButtons: true,
                                                onTapPod: { selectedPod = $0 }
                                            )
                                        }
                                    }
                                } else {
                                    friendsFeedContent
                                }
                            }
                        }

                        if lenny.phase == .idle {
                            // Leaves room so content doesn't hide behind the
                            // floating tab bar.
                            Color.clear.frame(height: 100)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newValue in
                    scrollState.updateOffset(newValue)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tapping anywhere that isn't a more specific control
                    // (the field itself, a chip, a pod card — those
                    // consume the tap first) collapses the search pill the
                    // same way submitting does. Attached to the ScrollView
                    // itself rather than its content — while Lenny's
                    // editing there's nothing below the pill yet, so the
                    // content is short and a catcher on just the VStack
                    // would leave most of the screen dead to this gesture.
                    //
                    // A Check-in/Checkout DatePicker's native calendar
                    // overlay renders outside the pill's own tap-
                    // absorbing bounds, so the tap that closes it (tapping
                    // outside the calendar) was escaping here and
                    // collapsing the whole pill instead of just the
                    // calendar. Consume exactly that one tap when a
                    // picker was just opened, then let tap-outside behave
                    // normally again — not suppressed for as long as
                    // filters happen to be open.
                    if filters.datePickerActive {
                        filters.datePickerActive = false
                    } else if homeSearch.isExpanded {
                        homeSearch.isExpanded = false
                    }
                }
                .background(Color.appHomeBackground)
            }
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
        // On the outer ZStack, not the ScrollView above — that branch is
        // torn down and rebuilt every time `selectedPod` toggles (feed <->
        // detail), which was re-running both fetches on every single "back"
        // tap. The ZStack's identity is stable for HomeView's whole
        // lifetime, so this now runs once.
        .task { await podsStore.fetchPods() }
        .task { await likesStore.fetchAll() }
        .task { await postsStore.fetchFeed() }
        // Points at the "Lenny" chip via the anchor it reports in
        // HomeSearchRow — attached up here rather than inside the
        // ScrollView branch so it renders on top of everything (feed
        // content included) instead of getting drawn over by whatever
        // sibling comes after the search row.
        .overlayPreferenceValue(LennyChipAnchorKey.self) { anchor in
            GeometryReader { geo in
                if let anchor, showLennyCoachmark, selectedPod == nil {
                    let rect = geo[anchor]
                    ZStack(alignment: .topLeading) {
                        // Dims/blurs the whole screen, uniformly — no
                        // cutout. A mask cut to the chip's plain layout
                        // bounds didn't line up with the Liquid Glass
                        // chip's actual rendered shape (glassEffect adds
                        // its own shimmer/highlight bleed beyond the
                        // Capsule's literal frame), so instead of a hole
                        // hoping to reveal the real chip in perfect
                        // alignment, a fresh chip is floated on top,
                        // below, positioned from the same anchor —
                        // alignment by construction, not by luck.
                        CoachmarkSpotlightScrim(onDismiss: dismissLennyCoachmark)

                        // Actually tappable, not just decorative — a
                        // coachmark that highlights a control and then
                        // eats the tap meant for it is a real
                        // anti-pattern (point at the thing, don't let
                        // them press the thing). Tapping it does exactly
                        // what the real underlying chip would.
                        CategoryChip(title: "Lenny", icon: "lenny") {
                            lenny.activate()
                            dismissLennyCoachmark()
                        }
                        .shadow(color: Color.appLennyAccent.opacity(0.45), radius: 14)
                        .position(x: rect.midX, y: rect.midY)

                        // Offset, not .position — .position needs the
                        // bubble's own width up front to center it, which
                        // would mean measuring it first (see
                        // HomeSearchRow's Save button for how much
                        // machinery that takes). Left-aligned, its leading
                        // edge just needs to land exactly on the chip's,
                        // which .offset gives for free relative to this
                        // ZStack's (0, 0) topLeading origin.
                        CoachmarkBubble(
                            message: "Switch to Lenny and describe your route — e.g. \"Chamonix to Zermatt in 5 days\" — and Lenny suggests pods along the way for you to compare and select.",
                            tailCenterOffset: rect.width / 2,
                            onDismiss: dismissLennyCoachmark
                        )
                        .offset(x: rect.minX, y: rect.maxY + 4)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .onChange(of: homeSearch.isExpanded) { _, expanded in
            guard expanded, !hasSeenLennyCoachmark, lenny.phase == .idle else {
                showLennyCoachmark = false
                return
            }
            // Let HomeSearchRow's own chip row finish fading in (its 0.18s
            // pause + 0.2s fade) before pointing at it, so the coachmark
            // doesn't appear above an empty space.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard homeSearch.isExpanded else { return }
                hasSeenLennyCoachmark = true
                withAnimation(.easeOut(duration: AppMotion.standard)) {
                    showLennyCoachmark = true
                }
            }
        }
        .onChange(of: lenny.phase) { _, phase in
            // Once they've actually engaged Lenny there's nothing left to
            // teach them.
            if phase != .idle { showLennyCoachmark = false }
        }
        .onChange(of: homeSearch.feedReselected) { _, _ in
            // BottomTabBar bumps this when Feed is tapped while already
            // the active tab — back to the actual root: out of any pod
            // detail, search collapsed, Lenny reset, same as if the tab
            // had never been touched.
            withAnimation(.easeOut(duration: AppMotion.standard)) {
                selectedPod = nil
            }
            homeSearch.isExpanded = false
            locationSearch = ""
            if lenny.phase != .idle {
                lenny.cancel()
            }
        }
        // Both triggers matter: a link tapped while the app is already
        // running fires the pendingPodId change first (pods are already
        // loaded by then); a cold launch from a link races fetchPods()
        // against .onOpenURL, so pods finishing the fetch is what
        // actually resolves it in that case.
        .onChange(of: deepLinkRouter.pendingPodId) { _, _ in resolveDeepLink() }
        .onChange(of: podsStore.pods) { _, _ in resolveDeepLink() }
        .onAppear {
            resolveDeepLink()
            // ScrollTrackingState is one singleton shared by every
            // scrollable tab — without this, switching in from a tab
            // scrolled down elsewhere could compute a spurious delta
            // against that stale offset and flash the tab bar's shrink
            // for a beat, unrelated to any actual scrolling here.
            scrollState.reset()
        }
    }

    private func dismissLennyCoachmark() {
        withAnimation(.easeIn(duration: AppMotion.quick)) {
            showLennyCoachmark = false
        }
    }

    /// Same pop-in-then-fade timing as `LikesStore.flashRecentLikeBadge`.
    private func flashRecentPostBadge() {
        recentPostBadgeTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) {
            showRecentPostBadge = true
        }
        recentPostBadgeTask = Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                showRecentPostBadge = false
            }
        }
    }

    /// Opens `PodDetailView` for whatever pod `DeepLinkRouter` is holding,
    /// once it's actually in `podsStore.pods` — a no-op otherwise (nothing
    /// pending, or pods haven't loaded far enough to include it yet).
    private func resolveDeepLink() {
        guard let podId = deepLinkRouter.pendingPodId else { return }
        guard let pod = podsStore.pods.first(where: { $0.id == podId }) else { return }
        selectedPod = pod
        deepLinkRouter.pendingPodId = nil
    }

    // MARK: - Friends' posts

    @ViewBuilder
    private var friendsFeedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friends' posts")
                    .font(AppFont.pillLabelBold(20))
                    .foregroundColor(.black)
                Spacer()
                Button { showPostComposer = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                }
                .accessibilityLabel("New post")
            }
            .padding(.horizontal, 24)

            if postsStore.posts.isEmpty {
                friendsEmptyState
            } else {
                VStack(spacing: 16) {
                    ForEach(postsStore.posts) { post in
                        PostCard(post: post, cardWidth: postCardWidth, onTapPod: {
                            if let pod = podsStore.pods.first(where: { $0.id == post.podId }) {
                                selectedPod = pod
                            }
                        }, onTapPhoto: {
                            selectedPost = post
                        })
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 16)
        // Same background-GeometryReader-plus-preference trick as
        // PodSection's own SectionWidthPreferenceKey — measured on this
        // section's own outer VStack (full device width, before its
        // internal 24pt horizontal padding below), then `postCardWidth`
        // subtracts that padding to get each PostCard's own exact width.
        // PostCard applies it as a hard `.frame(width:)`, not just a max,
        // so nothing inside it (an aspect-ratio computation gone wrong,
        // an offset stack, anything) can ever push the card wider than
        // its actual place in the feed.
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: PostsFeedWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(PostsFeedWidthPreferenceKey.self) { postsFeedAvailableWidth = $0 }
        .sheet(isPresented: $showPostComposer) {
            PostComposerView(onPosted: flashRecentPostBadge)
                // Half-height, not the default full sheet — same
                // presentation language as LikeFolderPickerSheet
                // (.large there; this one's short enough not to need it).
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var postCardWidth: CGFloat {
        postsFeedAvailableWidth - 48
    }

    private var friendsEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("No posts from friends yet — tap + to share one yourself.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - Feed states

    /// Same card-row shape as the launch skeleton (OnboardingView) — this
    /// fires right after that one, while `PodsStore.fetchPods()` is still
    /// in flight, so it reuses the same placeholder language instead of
    /// dropping back to a plain spinner + text. Mirrors `PodSection`'s own
    /// spacing exactly (`.padding(.vertical, 24)` per section, `spacing:
    /// 10` between title and cards, `.padding(.leading, 24)` on both) —
    /// anything looser here caused a visible jump once the real
    /// `PodSection`s replaced it.
    private var loadingState: some View {
        ForEach(0..<2, id: \.self) { _ in
            VStack(alignment: .leading, spacing: 10) {
                SkeletonShape(cornerRadius: AppRadius.r5)
                    .frame(width: 170, height: 18)
                    .padding(.leading, 24)

                HStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonShape(cornerRadius: AppRadius.r18)
                                .frame(width: podCardSkeletonSize, height: podCardSkeletonSize)
                            SkeletonShape(cornerRadius: AppRadius.r4)
                                .frame(width: podCardSkeletonSize * 0.55, height: 14)
                                .padding(.leading, 5)
                        }
                    }
                }
                .padding(.leading, 24)
            }
            .padding(.vertical, 24)
        }
    }

    /// Same sizing as `PodSection.cardSize` — two cards on screen plus a
    /// sliver of a third peeking at the trailing edge.
    private var podCardSkeletonSize: CGFloat {
        (UIScreen.main.bounds.width - 24 - 2 * 12 - 24) / 2
    }

    private var awaitingQueryState: some View {
        VStack(spacing: 12) {
            LennySearchAvatar()
            Text("Type a location to search.")
                .font(AppFont.regularLabel(14))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private var awaitingLennyQueryState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("Describe your hike and Lenny will find pods along the way.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text(emptyStateMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private var emptyStateMessage: String {
        if !locationSearch.isEmpty {
            return "No pods match \"\(locationSearch)\"."
        } else if filters.hikers > 0 {
            return "No pods sleep \(filters.hikers) or more."
        } else {
            return "No pods available yet."
        }
    }
}

/// Minimal two-segment "Pods / Friends" toggle switching Home's main
/// content between pod browsing and friends' posts. No pill/capsule chrome
/// — just the two labels (muted when inactive, black and underlined when
/// active) centered between a hairline rule stretching to each edge, same
/// divider language as OnboardingView's `DividerOr`.
private struct HomeFeedToggle: View {
    @Binding var selection: HomeFeedTab
    /// Transient "+1" on the "Friends" label — same self-clearing style
    /// as BottomTabBar's Likes tab, driven by HomeView's
    /// `flashRecentPostBadge`.
    var showFriendsBadge: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)

            HStack(spacing: 20) {
                ForEach(HomeFeedTab.allCases, id: \.self) { tab in
                    Text(tab.title)
                        .font(AppFont.pillLabelSemiBold(16))
                        .foregroundColor(selection == tab ? .black : .appTextMuted)
                        .underline(selection == tab, color: .black)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard selection != tab else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeOut(duration: AppMotion.standard)) {
                                selection = tab
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if tab == .friends && showFriendsBadge {
                                Text("+1")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.appTextMuted))
                                    .offset(x: 16, y: -8)
                                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                            }
                        }
                }
            }
            .fixedSize()

            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
        }
    }
}

#Preview {
    HomeView()
}

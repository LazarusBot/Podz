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
    @State private var postsFeedAvailableWidth: CGFloat = UIScreen.main.bounds.width
    /// Persisted so the coachmark only ever shows once, not once per
    /// session — not routing-related (see AuthManager's justRegistered
    /// note on the old hasSeenOnboarding bug), so plain @AppStorage is
    /// fine here.
    @AppStorage("podz.hasSeenLennyCoachmark") private var hasSeenLennyCoachmark = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if let pod = selectedPod {
                PodDetailView(pod: pod, onBack: { selectedPod = nil })
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

                                // Below every pod section, not above — only
                                // alongside the pod-browsing content, not
                                // while the search pill's own full-screen
                                // "awaiting a query" prompt is showing.
                                postsFeedSection
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
                        LennySpotlightScrim(onDismiss: dismissLennyCoachmark)

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
                        LennyCoachmark(tailCenterOffset: rect.width / 2, onDismiss: dismissLennyCoachmark)
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
    private var postsFeedSection: some View {
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
            }
            .padding(.horizontal, 24)

            if !postsStore.posts.isEmpty {
                VStack(spacing: 16) {
                    ForEach(postsStore.posts) { post in
                        PostCard(post: post, cardWidth: postCardWidth, onTapPod: {
                            if let pod = podsStore.pods.first(where: { $0.id == post.podId }) {
                                selectedPod = pod
                            }
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
            PostComposerView()
        }
    }

    private var postCardWidth: CGFloat {
        postsFeedAvailableWidth - 48
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
                SkeletonShape(cornerRadius: 5)
                    .frame(width: 170, height: 18)
                    .padding(.leading, 24)

                HStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonShape(cornerRadius: 18)
                                .frame(width: podCardSkeletonSize, height: podCardSkeletonSize)
                            SkeletonShape(cornerRadius: 4)
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
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("Type a location to search.")
                .font(.system(size: 14, weight: .medium))
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

/// Dims and softly blurs the whole screen uniformly while the coachmark
/// is up, so the floating chip clone + bubble above it read as the one
/// thing in focus without a literal cutout to keep pixel-aligned against
/// (see the call site for why that approach got dropped). Both layers
/// are deliberately light — .ultraThinMaterial is already the softest
/// blur Material offers, and scaling it down further via .opacity keeps
/// this a gentle focus cue rather than a heavy-handed dimming.
private struct LennySpotlightScrim: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.14)
            Rectangle().fill(.ultraThinMaterial).opacity(0.5)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .transition(.opacity)
    }
}

/// First-time tip pointing at the search pill's "Lenny" chip — shown once
/// (see `hasSeenLennyCoachmark`) the first time someone opens the search
/// pill, so they know it's not just a plain location search. A single
/// custom outline (`CoachmarkBubbleShape`) rather than a rounded rect
/// plus a separate triangle glued underneath it — fill and stroke both
/// trace the tail and body as one continuous edge, so there's no seam
/// where a two-shape version would show a visible stroke line across the
/// tail's base.
private struct LennyCoachmark: View {
    /// Tail center's distance from the bubble's leading edge. The bubble
    /// itself stays left-aligned to the chip (see the call site's
    /// `.offset`), but the tail is passed the chip's own width so it can
    /// point at the chip's actual midpoint instead of just wherever
    /// happens to be near the bubble's leading edge.
    var tailCenterOffset: CGFloat
    var onDismiss: () -> Void

    private let tailWidth: CGFloat = 16
    private let tailHeight: CGFloat = 9
    private let cornerRadius: CGFloat = 16

    private var shape: CoachmarkBubbleShape {
        CoachmarkBubbleShape(cornerRadius: cornerRadius, tailWidth: tailWidth, tailHeight: tailHeight, tailInset: tailCenterOffset)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // A plain info glyph, not a feature icon — this is explaining
            // what the control is, not illustrating the hike itself.
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            // mediumLabel (Inter), not pillLabelMedium (Darker Grotesque)
            // — Darker Grotesque is the display face used for big chip
            // labels/numbers and reads thin at paragraph size even at its
            // own Medium weight; Inter Medium is the app's actual body
            // font elsewhere in this screen (Lenny's status text, error
            // messages) and carries more visual weight here.
            Text("Switch to Lenny and describe your route — e.g. \"Chamonix to Zermatt in 5 days\" — and Lenny suggests pods along the way for you to compare and select.")
                .font(AppFont.mediumLabel(15))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.top, tailHeight + 14)
        .padding(.bottom, 14)
        .background(shape.fill(Color.appAccentBlack))
        .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topLeading)))
    }
}

/// Rounded rect with a speech-bubble tail on its top edge, traced as one
/// outline via tangent-based corners (`addArc(tangent1End:tangent2End:)`)
/// rather than angle-based arcs — direction-agnostic, so there's no risk
/// of the usual clockwise/flipped-Y sign mistakes that angle math invites.
private struct CoachmarkBubbleShape: Shape {
    var cornerRadius: CGFloat
    var tailWidth: CGFloat
    var tailHeight: CGFloat
    var tailInset: CGFloat

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY + tailHeight, width: rect.width, height: rect.height - tailHeight)
        let r = min(cornerRadius, body.width / 2, body.height / 2)
        let tailCenterX = min(max(rect.minX + tailInset, body.minX + r + tailWidth / 2), body.maxX - r - tailWidth / 2)

        var path = Path()
        path.move(to: CGPoint(x: body.minX + r, y: body.minY))
        path.addLine(to: CGPoint(x: tailCenterX - tailWidth / 2, y: body.minY))
        path.addLine(to: CGPoint(x: tailCenterX, y: rect.minY))
        path.addLine(to: CGPoint(x: tailCenterX + tailWidth / 2, y: body.minY))
        path.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + r), radius: r)
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - r, y: body.maxY), radius: r)
        path.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - r), radius: r)
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + r, y: body.minY), radius: r)
        path.closeSubpath()
        return path
    }
}

#Preview {
    HomeView()
}

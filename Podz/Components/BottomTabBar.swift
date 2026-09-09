import SwiftUI
internal import Auth

enum HomeTab: String, CaseIterable {
    case feed = "Feed"
    case likes = "Likes"
    case pods = "Pods"
    case mailbox = "Mailbox"
    case profile = "Profile"

    /// Custom asset name (Figma export), inactive/outline state.
    var iconName: String {
        switch self {
        case .feed: return "compas"
        case .likes: return "likes"
        case .pods: return "pods"
        case .mailbox: return "mailbox"
        case .profile: return "" // uses AvatarView instead
        }
    }

    /// Custom asset name, active/filled state.
    var iconNameActive: String {
        iconName.isEmpty ? "" : "\(iconName)-active"
    }

    /// SF Symbol fallback for `TabBarIcon` if the custom asset above is
    /// ever missing — in practice never hit, since every hiker tab's
    /// asset ships with the app, but `TabBarIcon` is shared with
    /// `HostTabBar` now, whose own Tasks/Guests tabs rely on exactly
    /// this fallback path having a real icon behind it.
    var systemFallback: String {
        switch self {
        case .feed: "safari"
        case .likes: "heart"
        case .pods: "house"
        case .mailbox: "envelope"
        case .profile: ""
        }
    }
}

/// Floating pill tab bar (node 4172:377). Sits absolutely over the
/// scroll content — margins (24pt horizontal, no added bottom margin —
/// tried 6pt and 12pt, both read as no different from the safe-area
/// inset alone) are set where it's placed, in `MainTabView`, not here.
///
/// Deliberately lighter than Figma's spec (near-transparent
/// `rgba(0,0,0,0.1)`) — swapped to a white-tinted Liquid Glass
/// (`.glassEffect`, 0.4 opacity) plus a gray capsule that slides behind
/// the active tab (2026-08-27 restyle). Icon/label colors flipped from
/// white to black/`.appTextMuted` to stay legible against the lighter
/// background. Labels themselves were dropped later that same day —
/// icon-only, sized/padded/spaced past Apple's ~56pt reference height
/// for a floating tab bar (landed around 64pt), with real gaps between
/// tabs instead of edge-to-edge columns.
///
/// Tab selection is a plain tap now, not the old press-and-drag-across
/// gesture — that mechanic (per-tab frame measurement, hold thresholds,
/// settle timers) existed only to let a finger slide between tabs
/// without lifting, which turned out to be more machinery than the
/// interaction was worth. The one gesture worth keeping the extra
/// complexity for is the Profile tab's own long-press, which reveals
/// `ModeSwitchPill` — see `profileModeSwitch` below.
struct BottomTabBar: View {
    @Binding var selected: HomeTab
    var profileImageName: String? = nil
    @ObservedObject private var likesStore = LikesStore.shared
    @ObservedObject private var messagesStore = MessagesStore.shared
    @ObservedObject private var postsStore = PostsStore.shared
    @ObservedObject private var reservationsStore = ReservationsStore.shared
    @ObservedObject private var appMode = AppModeStore.shared
    /// New (unseen) likes/comments on your own posts — same source
    /// PostsActivityView itself reads, just reduced to a plain presence
    /// check for the dot.
    private var hasNewPostActivity: Bool {
        guard let userId = AuthManager.shared.session?.user.id else { return false }
        return postsStore.newActivityCount(onPostsAuthoredBy: userId) > 0
    }
    /// Each tab's own on-screen frame — sizing/positioning the sliding
    /// selection pill only needs this now (no more hit-testing a drag
    /// against it, since selection is a plain tap per tab).
    @State private var tabFrames: [HomeTab: CGRect] = [:]
    /// True while `ModeSwitchPill` is up, revealed by a long press on
    /// the Profile tab — see `profileModeSwitch`.
    @State private var isModeSwitchRevealed = false
    /// 0...1 drag progress of the pill's handle, owned here so it can be
    /// reset the instant the switch commits (closing the pill mid-way
    /// through its own commit action would otherwise show the handle
    /// snapping back before the fade-out even starts).
    @State private var modeSwitchProgress: CGFloat = 0
    /// True for the instant between the Profile tab's long press firing
    /// (revealing the pill, finger still down) and that same touch's
    /// release — swallows the plain-tap `.onTapGesture` that release
    /// would otherwise also fire (they're `.simultaneousGesture`, not
    /// exclusive, specifically so the long press doesn't block a normal
    /// short tap — see `ProfileLongPress`). Safe to set/check without a
    /// race: `LongPressGesture.onEnded` always fires at the duration
    /// threshold, strictly before the release that fires `onTapGesture`.
    @State private var suppressNextProfileTap = false
    /// First-time tip pointing at the Profile tab's own long-press —
    /// same idea as HomeView's Lenny coachmark (see `CoachmarkBubble`),
    /// shown once to hosts who haven't discovered the gesture yet.
    @State private var showModeSwitchCoachmark = false
    /// Measured so the bubble can be right-aligned to the Profile tab's
    /// own trailing edge (it sits at the far right of the row, so a
    /// left-aligned bubble — the Lenny coachmark's own approach — would
    /// run off the right edge of the screen instead). Seeded with a
    /// reasonable guess, not `.zero`, so the very first frame (before
    /// `onGeometryChange` reports the real size) still lands close to
    /// right instead of visibly jumping into place a frame later.
    @State private var modeSwitchCoachmarkBubbleSize = CGSize(width: 300, height: 90)
    /// Persisted so this only ever shows once, not once per session —
    /// same reasoning as HomeView's own `hasSeenLennyCoachmark`.
    @AppStorage("podz.hasSeenModeSwitchCoachmark") private var hasSeenModeSwitchCoachmark = false

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    tabRow
                        .glassEffect(.regular.tint(.white.opacity(0.4)), in: .capsule)
                }
            } else {
                // Pre-iOS 26 fallback: closest approximation with materials.
                tabRow
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().fill(Color.white.opacity(0.4)))
                    )
            }
        }
        .overlay(
            // Figma only specifies a top hairline, not a full border.
            Capsule()
                .strokeBorder(Color.appBorder, lineWidth: 0.5)
        )
        .overlay(alignment: .top) {
            if isModeSwitchRevealed {
                ModeSwitchPill(
                    label: appMode.mode == .host ? "Switch to hiker mode ?" : "Switch to hosting mode ?",
                    progress: $modeSwitchProgress,
                    onCommit: commitModeSwitch,
                    // Instant, not the animated spring — a below-
                    // threshold release reads as "changed their mind,"
                    // same as a tap outside the pill, so it gets the
                    // same immediate dismiss rather than a fade/spring
                    // that makes an already-abandoned gesture linger.
                    onCancel: dismissModeSwitchInstantly
                )
                .offset(y: -60)
                // `.background`, not a `ZStack` sibling — a sibling's
                // huge 2000x2000 frame would make the *whole stack* size
                // to it, which shifts where "center" is and throws off
                // this pill's own `.offset(y: -60)` (it landed hundreds
                // of points off-screen the first time). `.background`
                // doesn't propose its own size upward — the reported
                // layout size stays the pill's own small footprint, with
                // the catcher just painted (and hit-testable) behind it
                // without disturbing that.
                .background(ModeSwitchDismissCatcher(onDismiss: dismissModeSwitchInstantly))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(1)
            }
        }
        .overlay(alignment: .top) {
            if showModeSwitchCoachmark, let profileRect = tabFrames[.profile] {
                // `tabFrames` is measured in the "tabRow" named space
                // (`tabRow`'s own pre-padding origin — see its own
                // `.coordinateSpace`), but this overlay sits on the
                // outer `Group`, *after* `tabRow`'s own 24/13 padding —
                // converting into that space is what makes this rect
                // line up with the real, on-screen Profile tab instead
                // of landing 24pt left and 13pt above it.
                let rect = profileRect.offsetBy(dx: 24, dy: tabRowVerticalPadding)
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        CoachmarkSpotlightScrim(onDismiss: dismissModeSwitchCoachmark)

                        // A floating clone of the real avatar, positioned
                        // exactly over the Profile tab — same "align by
                        // construction" reasoning as HomeView's own Lenny
                        // chip clone (see its own comment for why a
                        // literal cutout mask isn't used instead).
                        AvatarView(imageName: profileImageName, size: 26)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.35), radius: 10)
                            .position(x: rect.midX, y: rect.midY)
                            .contentShape(Circle())
                            .onTapGesture(perform: dismissModeSwitchCoachmark)

                        // Right-aligned to the tab's own trailing edge,
                        // pointing down — the Profile tab sits at the far
                        // right of the row and near the bottom of the
                        // screen, the opposite corner from Lenny's chip,
                        // so both the bubble's own alignment and its
                        // tail direction flip relative to that coachmark.
                        CoachmarkBubble(
                            message: "Long-press and swipe right on your profile to switch into hosting mode.",
                            tailCenterOffset: rect.midX - (rect.maxX - modeSwitchCoachmarkBubbleSize.width),
                            pointsDown: true,
                            onDismiss: dismissModeSwitchCoachmark
                        )
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { modeSwitchCoachmarkBubbleSize = $0 }
                        .offset(
                            x: rect.maxX - modeSwitchCoachmarkBubbleSize.width,
                            y: rect.minY - 4 - modeSwitchCoachmarkBubbleSize.height
                        )
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .zIndex(2)
            }
        }
        .task {
            // Only hosts actually have anything to switch to — showing
            // this to a plain hiker account would point at a gesture
            // that, per OnboardingView's own routing, does nothing for
            // them. `.mode == .hiker` guards against re-showing this to
            // someone who already found their way into host mode some
            // other way (the Profile menu, before this existed) without
            // ever triggering this specific gesture.
            guard
                AuthManager.shared.profile?.isHost == true,
                appMode.mode == .hiker,
                !hasSeenModeSwitchCoachmark
            else { return }
            // Same reasoning as HomeView's own Lenny coachmark: let
            // whatever brought this bar on screen finish its own
            // entrance first, so the coachmark doesn't appear pointing
            // at a tab bar still mid-transition.
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard AuthManager.shared.profile?.isHost == true, appMode.mode == .hiker else { return }
            hasSeenModeSwitchCoachmark = true
            withAnimation(.easeOut(duration: AppMotion.standard)) {
                showModeSwitchCoachmark = true
            }
        }
        .onChange(of: isModeSwitchRevealed) { _, revealed in
            // Once they've actually triggered the real gesture themselves
            // there's nothing left to teach them.
            if revealed { dismissModeSwitchCoachmark() }
        }
    }

    private var tabRow: some View {
        // 20 — with labels gone, edge-to-edge columns read as cramped
        // icons with nothing separating them; a real gap between each
        // tab's own zone (and so its own pill) is what actually makes
        // the bar feel breathable, not just shorter. Bumped from 12,
        // then 16, now that the pill itself is bigger too, so there's
        // still real separation between adjacent pills, not just
        // adjacent icons.
        HStack(spacing: 20) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                tabContent(tab)
                    .frame(maxWidth: .infinity)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named("tabRow"))
                    } action: { frame in
                        tabFrames[tab] = frame
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { handleTap(tab) }
                    .modifier(ProfileLongPress(isActive: tab == .profile, onLongPress: revealModeSwitch))
            }
        }
        .coordinateSpace(name: "tabRow")
        .background(alignment: .topLeading) { pillOverlay }
        .padding(.horizontal, 24)
        .padding(.vertical, tabRowVerticalPadding)
    }

    @ViewBuilder
    private var pillOverlay: some View {
        if let frame = tabFrames[selected] {
            pill
                .frame(width: frame.width + pillGrowthX * 2, height: frame.height + pillGrowthY * 2)
                .offset(x: frame.midX - (frame.width + pillGrowthX * 2) / 2, y: frame.midY - (frame.height + pillGrowthY * 2) / 2)
                .animation(pillSpring, value: selected)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: HomeTab) -> some View {
        let isHighlighted = tab == selected

        // Icon-only now — no label underneath (see the sizing note
        // below) — so this is just a single-child container rather than
        // an actual vertical stack of icon + text.
        Group {
            if tab == .profile {
                AvatarView(imageName: profileImageName, size: 26)
                    .overlay(
                        Circle().strokeBorder(Color.black, lineWidth: isHighlighted ? 1.5 : 0)
                    )
                    .scaleEffect(isHighlighted ? 1.08 : 1)
                    .overlay(alignment: .topTrailing) {
                        // A plain dot, not a count pill — the count
                        // itself already shows on the Posts row inside
                        // Profile; this just needs to say "something's
                        // there" from the tab bar.
                        if hasNewPostActivity {
                            Circle()
                                .fill(Color.appMessageBlue)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                        }
                    }
            } else {
                TabBarIcon(
                    assetName: tab.iconName,
                    activeAssetName: tab.iconNameActive,
                    systemFallback: tab.systemFallback,
                    isActive: isHighlighted
                )
                    // Anchored to the icon's own bounds, not the tab's
                    // full flexible-width column — that column spans a
                    // fifth of the bar's width, so .topTrailing on it
                    // landed the badge well past the actual heart icon
                    // instead of right over it.
                    .overlay(alignment: .topTrailing) {
                        // Transient "+1", not a persistent count — a
                        // "that just happened" confirmation for a like
                        // added elsewhere (Home), not a running
                        // unread-style badge, so it self-clears rather
                        // than sticking around like a notification count.
                        if tab == .likes && likesStore.showRecentLikeBadge {
                            // White text on an .appTextMuted fill — same
                            // gray family as the inactive tabs.
                            Text("+1")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.appTextMuted))
                                .offset(x: 12, y: -6)
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                        } else if tab == .pods && reservationsStore.showRecentReservationBadge {
                            // Identical treatment to the likes "+1" above
                            // — same transient "that just happened"
                            // confirmation, just for a reservation made
                            // elsewhere (ReservationSheet) instead of a
                            // like.
                            Text("+1")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.appTextMuted))
                                .offset(x: 12, y: -6)
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                        } else if tab == .mailbox && messagesStore.unreadCount > 0 {
                            // Persistent, not self-clearing like the
                            // likes "+1" — reflects real unread state
                            // directly, so it stays up the whole time
                            // there's something unread rather than
                            // flashing once after an action. Blue to
                            // match the Mailbox feature's own accent
                            // (sent bubbles, the conversation list's own
                            // unread dot), not the neutral gray above.
                            Text(messagesStore.unreadCount > 9 ? "9+" : "\(messagesStore.unreadCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                // A single digit alone is nearly as tall
                                // as it is wide, so the exact same
                                // Capsule() the "+1" badge uses collapses
                                // toward a circle instead of reading as a
                                // pill — "+1" is just wider text. This
                                // floor keeps it visibly wider than tall
                                // for 1- and 2-digit counts alike.
                                .frame(minWidth: 18)
                                .background(Capsule().fill(Color.appMessageBlue))
                                .offset(x: 7, y: -6)
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                        }
                    }
                    // The likes "+1" already animates in via LikesStore's
                    // own `withAnimation` around `showRecentLikeBadge` —
                    // this badge's source (`unreadCount`, changed by
                    // `markRead`/realtime inserts/`send`) isn't wrapped
                    // in one anywhere, so without this it would just
                    // pop in/out instead of transitioning.
                    .animation(.easeOut(duration: AppMotion.snappy), value: messagesStore.unreadCount)
            }
        }
        // Paired with the row's own 13pt vertical padding, lands the bar
        // around 64pt tall (26 + 6×2 + 13×2) — sized up a bit past
        // Apple's ~56pt floating-tab-bar reference on request, rather
        // than landing exactly on it.
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isHighlighted ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { commitSelection(tab) }
    }

    /// The single gray pill — sized/positioned by `pillOverlay` off the
    /// active tab's own measured frame, styled here.
    private var pill: some View {
        Capsule().fill(Color.gray.opacity(0.16))
    }

    /// Drives the pill's slide between tabs.
    private let pillSpring: Animation = .spring(response: 0.28, dampingFraction: 0.85)

    /// `tabRow`'s own vertical padding — named so it's one number
    /// instead of a repeated literal.
    private let tabRowVerticalPadding: CGFloat = 13

    /// Added to each side of the active tab's own measured width/height
    /// — asymmetric on purpose (X well past Y) so it reads as an actual
    /// wide pill rather than a squarish blob hugging the icon or a tall
    /// rounded rectangle.
    private let pillGrowthX: CGFloat = 18
    private let pillGrowthY: CGFloat = 6

    private func commitSelection(_ tab: HomeTab) {
        if tab == selected {
            // Re-tapping the already-active tab doesn't change `selected`
            // (same value in, same value out — no onChange to hook), so
            // Feed's "go back to root" reset needs its own explicit
            // signal instead of piggybacking on the tab switch.
            if tab == .feed {
                HomeSearchState.shared.feedReselected += 1
            }
        } else {
            withAnimation(.easeOut(duration: AppMotion.quick)) {
                selected = tab
            }
        }
    }

    private func handleTap(_ tab: HomeTab) {
        if tab == .profile && suppressNextProfileTap {
            suppressNextProfileTap = false
            return
        }
        commitSelection(tab)
    }

    private func revealModeSwitch() {
        suppressNextProfileTap = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isModeSwitchRevealed = true
        }
    }

    private func dismissModeSwitch() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isModeSwitchRevealed = false
            modeSwitchProgress = 0
        }
    }

    /// A tap genuinely outside the pill (`ModeSwitchDismissCatcher`)
    /// closes it right away — no spring, no fade — unlike a below-
    /// threshold drag release, which still gets `dismissModeSwitch`'s
    /// animated snap-back above.
    private func dismissModeSwitchInstantly() {
        isModeSwitchRevealed = false
        modeSwitchProgress = 0
    }

    private func commitModeSwitch() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        appMode.mode = appMode.mode == .host ? .hiker : .host
        dismissModeSwitch()
    }

    private func dismissModeSwitchCoachmark() {
        withAnimation(.easeIn(duration: AppMotion.quick)) {
            showModeSwitchCoachmark = false
        }
    }
}

/// Attaches a long-press-only gesture to one tab's content — kept as its
/// own modifier rather than an inline `.onLongPressGesture` in
/// `tabContent` so the same "which tab, which callback" shape can be
/// reused verbatim by `HostTabBar`.
struct ProfileLongPress: ViewModifier {
    let isActive: Bool
    let onLongPress: () -> Void

    func body(content: Content) -> some View {
        if isActive {
            // `.simultaneousGesture`, not `.gesture`/`.onLongPressGesture`
            // — those compete exclusively with the tab's own
            // `.onTapGesture` already attached above (SwiftUI gives the
            // last-attached gesture precedence), which risks swallowing
            // plain taps on Profile entirely. Simultaneous recognition is
            // the documented way to add a long press alongside an
            // existing tap without either blocking the other.
            content.simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4).onEnded { _ in onLongPress() }
            )
        } else {
            content
        }
    }
}

/// Picks the right icon for the current state: custom "active" asset if
/// active + present, custom base asset if present, else an SF Symbol
/// fallback — shared with `HostTabBar` (not `private` here on purpose)
/// so a host tab that reuses one of the hiker shell's own icons
/// (Mailbox, My Pods) renders the exact same glyph instead of falling
/// back to a different, generic system one. `assetName`/`activeAssetName`
/// are `nil` for a tab with no export of its own yet (Tasks, Guests),
/// which just goes straight to `systemFallback`.
struct TabBarIcon: View {
    var assetName: String? = nil
    var activeAssetName: String? = nil
    let systemFallback: String
    let isActive: Bool

    private var resolvedAsset: String? {
        let preferred = isActive ? (activeAssetName ?? assetName) : assetName
        if let preferred, UIImage(named: preferred) != nil {
            return preferred
        }
        // Active variant not exported yet — keep the base look but with
        // the active color/weight, rather than falling all the way back
        // to the system glyph.
        if let assetName, UIImage(named: assetName) != nil {
            return assetName
        }
        return nil
    }

    var body: some View {
        Group {
            if let resolvedAsset {
                Image(resolvedAsset)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: systemFallback)
                    .font(.system(size: 20, weight: .semibold))
            }
        }
        // 26, not 24 — icon-only now that the label's gone, so the icon
        // carries the tab's whole presence instead of sharing it with
        // text underneath; a touch bigger keeps it from looking small
        // and lost in the taller touch target.
        .frame(width: 26, height: 26)
        .foregroundColor(isActive ? .black : .appTextMuted)
        .scaleEffect(isActive ? 1.08 : 1)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.appHomeBackground.ignoresSafeArea()
        BottomTabBar(selected: .constant(.feed))
            // Matches MainTabView's actual values, not a canvas-only guess.
            .padding(.horizontal, 24)
    }
}

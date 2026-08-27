import SwiftUI

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
/// Second attempt at the drag-across-tabs gesture. The first attempt
/// computed each segment's rect by dividing the measured row width by 5
/// and subtracting the outer padding by hand — that math had a bug
/// somewhere (never isolated) that pinned the touch resolution to index
/// 0, so the whole bar looked dead. This version never computes a
/// segment's rect — each tab's `Button` reports its own real frame via
/// `.onGeometryChange`, in a shared named coordinate space, into
/// `tabFrames`; hit-testing is then just "which measured rect contains
/// this point," with a nearest-center fallback so an edge/rounding miss
/// can never fail to resolve to *some* tab. Less arithmetic to get wrong.
struct BottomTabBar: View {
    @Binding var selected: HomeTab
    var profileImageName: String? = nil
    @ObservedObject private var likesStore = LikesStore.shared
    @ObservedObject private var messagesStore = MessagesStore.shared
    /// Each tab's own on-screen frame, in the "tabRow" named coordinate
    /// space — populated by every tab's `.onGeometryChange` as soon as
    /// layout settles, read by the drag gesture to resolve a touch point
    /// to a tab, and by the pill to size/position itself.
    @State private var tabFrames: [HomeTab: CGRect] = [:]
    /// The tab currently under the finger while a touch is down, OR
    /// still settling into its post-release position — nil only once
    /// both the finger is up *and* the settle animation has finished, at
    /// which point the pill falls back to `selected`. Drives *position*
    /// only now — growth/glass are gated on `isHolding` instead (see
    /// below), so a plain tap doesn't pop/shrink at all, just slides.
    @State private var draggedTab: HomeTab?
    /// True once the current touch has been down past `holdThreshold`
    /// without releasing — a genuine press or drag, as opposed to a
    /// quick tap. Only this drives the pill's grow/glass look.
    @State private var isHolding = false
    /// Starts on touch-down, fires `isHolding = true` after
    /// `holdThreshold` — cancelled on release, so a tap shorter than the
    /// threshold never sets it at all.
    @State private var holdTask: Task<Void, Never>?
    /// Clears `draggedTab`/`isHolding` after the settle animation's own
    /// duration — cancelled and restarted on every new touch so a fast
    /// second tap doesn't let a stale timer null them out mid-drag.
    @State private var settleTask: Task<Void, Never>?

    private var displayedTab: HomeTab { draggedTab ?? selected }

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
            }
        }
        // Named directly on the HStack, before anything else touches it
        // — every button's measured frame and the pill's placement below
        // both need to agree on the exact same origin (this view's own
        // pre-padding top-left corner), or they drift apart by whatever
        // padding sits between them.
        .coordinateSpace(name: "tabRow")
        // `.background`, not a ZStack/outer-layer sibling — living
        // nested here means the pill inherits `.glassEffect(_, in:
        // .capsule)`'s clip to the bar's own outline, which reads better
        // than a pill popping out past the bar's edges while pressed.
        .background(alignment: .topLeading) {
            pillOverlay
        }
        .padding(.horizontal, 24)
        .padding(.vertical, tabRowVerticalPadding)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("tabRow"))
                .onChanged { value in
                    settleTask?.cancel()
                    // `holdTask == nil` is what identifies this as the
                    // first `onChanged` of a fresh touch (it's cleared
                    // in `onEnded` below) — start the hold-threshold
                    // timer exactly once per touch, not on every update
                    // as a drag moves across tabs.
                    if holdTask == nil {
                        holdTask = Task {
                            try? await Task.sleep(nanoseconds: 130_000_000)
                            guard !Task.isCancelled else { return }
                            isHolding = true
                        }
                    }
                    draggedTab = tab(at: resolvedLocation(for: value))
                }
                .onEnded { value in
                    // Cancelling here (not letting it run out) is what
                    // makes a quick tap never grow at all — released
                    // before `holdThreshold`, so `isHolding` never
                    // flips true, and the tap plays as a plain slide.
                    holdTask?.cancel()
                    holdTask = nil
                    if let tab = tab(at: resolvedLocation(for: value)) {
                        commitSelection(tab)
                    }
                    // Don't clear `draggedTab`/`isHolding` immediately —
                    // for a genuine press/drag, that made the post-
                    // release settle slide play with the flat resting
                    // fill instead of glass, since by the time the
                    // pill's own position animation started, `isHolding`
                    // was already false. Hold both through the settle
                    // animation instead, then clear them. Matches
                    // `pillGrowthSpring`'s own settle time (0.5s
                    // response, 0.9 damping — settles in roughly
                    // 1.3-1.4x that), the slower of the two pill
                    // springs — clearing any sooner flips `isHolding`
                    // back to false (shrinking the pill) before growth
                    // even finishes expanding it, which looked like the
                    // growth reversing mid-motion. Harmless no-op for a
                    // plain tap, where `isHolding` was never true.
                    settleTask?.cancel()
                    settleTask = Task {
                        try? await Task.sleep(nanoseconds: 680_000_000)
                        guard !Task.isCancelled else { return }
                        draggedTab = nil
                        isHolding = false
                    }
                }
        )
    }

    /// Sized to the active tab's own measured frame, grown by an explicit
    /// width/height *added to the frame itself* (asymmetric — much more
    /// on X than Y, which is what actually makes it read as a wide,
    /// short pill rather than a tall rounded rectangle). Reverted from a
    /// brief detour into insetting from the bar's full height instead —
    /// that filled almost the entire bar vertically and stopped looking
    /// like a pill at all, which wasn't the ask; "take more place" meant
    /// bigger, not a different shape. Not `.scaleEffect(x: y:)` either —
    /// that was an earlier, separate bug: scaling a `Capsule()`'s two
    /// axes by different factors stretches its round ends into ellipses
    /// instead of keeping them circular. Growing the frame directly lets
    /// `Capsule()` compute its own correct rounding for whatever
    /// width/height it's actually given.
    @ViewBuilder
    private var pillOverlay: some View {
        if let frame = tabFrames[displayedTab] {
            let growthX = isHolding ? pillPressedGrowthX : pillRestingGrowthX
            let growthY = isHolding ? pillPressedGrowthY : pillRestingGrowthY
            let pillWidth = frame.width + growthX * 2
            let pillHeight = frame.height + growthY * 2
            pill
                .frame(width: pillWidth, height: pillHeight)
                // Scoped to the frame specifically, watching only
                // `isHolding` — a plain tap never sets `isHolding` at
                // all now (see the gesture above), so it just slides;
                // for a genuine press/drag, the growth is a small pixel
                // delta next to a potentially full-bar-width position
                // change, so under a matched spring the growth visually
                // finished long before the travel did. `pillGrowthSpring`
                // is deliberately slower so it stays visibly in motion
                // for close to as long as a full slide takes, instead of
                // racing ahead of it.
                .animation(pillGrowthSpring, value: isHolding)
                // `.offset`, not `.position` — `.position` made this view
                // (and its old ZStack parent) report a greedy, unbounded
                // ideal size upward, which is why the whole bar once
                // ballooned to fill the screen. `.offset` translates
                // without touching layout sizing at all, so with
                // `.topLeading` alignment the top-left-corner math below
                // lands the pill's *center* at the tab's own center.
                .offset(x: frame.midX - pillWidth / 2, y: frame.midY - pillHeight / 2)
                .animation(pillSpring, value: displayedTab)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: HomeTab) -> some View {
        let isHighlighted = tab == displayedTab

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
            } else {
                TabIcon(tab: tab, isActive: isHighlighted)
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
                                .offset(x: 12, y: -6)
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                        }
                    }
                    // The likes "+1" already animates in via LikesStore's
                    // own `withAnimation` around `showRecentLikeBadge` —
                    // this badge's source (`unreadCount`, changed by
                    // `markRead`/realtime inserts/`send`) isn't wrapped
                    // in one anywhere, so without this it would just
                    // pop in/out instead of transitioning.
                    .animation(.easeOut(duration: 0.2), value: messagesStore.unreadCount)
            }
        }
        // Paired with the row's own 13pt vertical padding, lands the bar
        // around 64pt tall (26 + 6×2 + 13×2) — sized up a bit past
        // Apple's ~56pt floating-tab-bar reference on request, rather
        // than landing exactly on it.
        .padding(.vertical, 6)
        // The row's own gesture drives selection now (there's no Button
        // per tab any more, so it can track a finger sliding across
        // segments) — this keeps each tab a real accessibility element
        // with a working activate action for VoiceOver.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isHighlighted ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { commitSelection(tab) }
    }

    /// The single gray pill — sized/positioned by `pillOverlay` off the
    /// active tab's own measured frame, styled here.
    private var pill: some View {
        Group {
            if isHolding, #available(iOS 26, *) {
                // Glass only while genuinely held/dragging (not a plain
                // tap — see `isHolding`), as a "grabbed" cue — sitting
                // still behind an icon/label the rest of the time,
                // full-time glass read as too heavy. Deliberately NOT
                // `.interactive()` — that variant installs its own touch
                // handling, which is what broke this row's own drag
                // gesture the first time around.
                Color.clear
                    .glassEffect(.regular.tint(Color.gray.opacity(0.1)), in: .capsule)
            } else {
                // Resting (or pre-iOS 26, which never gets glass): a
                // plain translucent gray fill.
                Capsule()
                    .fill(Color.gray.opacity(isHolding ? 0.2 : 0.16))
            }
        }
    }

    /// Drives the pill's slide between tabs.
    private let pillSpring: Animation = .spring(response: 0.28, dampingFraction: 0.85)
    /// Drives the pill's press-triggered growth — deliberately slower
    /// than `pillSpring` (see `pillOverlay`) to compensate for growth
    /// being a much smaller pixel delta than a cross-bar slide, which
    /// otherwise finishes animating well before the slide does even
    /// under an identical curve.
    private let pillGrowthSpring: Animation = .spring(response: 0.5, dampingFraction: 0.9)

    /// `tabRow`'s own vertical padding — named so it's one number
    /// instead of a repeated literal.
    private let tabRowVerticalPadding: CGFloat = 13

    /// Resting growth, added to each side of the tab's own measured
    /// width/height — asymmetric on purpose (X well past Y) so it reads
    /// as an actual wide pill rather than a squarish blob hugging the
    /// icon or a tall rounded rectangle. Sized up from 14/4 on request —
    /// same shape, more presence.
    private let pillRestingGrowthX: CGFloat = 18
    private let pillRestingGrowthY: CGFloat = 6
    /// Pressed growth — a further step up, same proportions.
    private let pillPressedGrowthX: CGFloat = 22
    private let pillPressedGrowthY: CGFloat = 9

    /// Below `tapMovementTolerance` of total travel, resolve against
    /// where the finger went *down* — natural tremor during a tap can
    /// carry a finger a few points sideways with zero intent to drag,
    /// and with a `minimumDistance: 0` gesture, that tremor alone could
    /// previously cross a tab boundary and select the neighboring tab
    /// on release. This is a real precision issue, not a cosmetic one:
    /// a raw drag gesture has no built-in tap/drag distinction the way
    /// `Button` did, so this dead zone reintroduces one — small movement
    /// still reads as "the tab I put my finger on," and only travel that
    /// clearly exceeds ordinary tremor counts as an intentional slide,
    /// at which point it tracks the live finger position instead.
    private func resolvedLocation(for value: DragGesture.Value) -> CGPoint {
        let movement = hypot(value.translation.width, value.translation.height)
        return movement < tapMovementTolerance ? value.startLocation : value.location
    }
    private let tapMovementTolerance: CGFloat = 12

    /// Which measured tab frame `point` falls in — falls back to the tab
    /// whose horizontal center is closest, so a touch landing exactly on
    /// a boundary (or a stale/rounding-off frame) always resolves to
    /// *some* tab instead of silently doing nothing.
    private func tab(at point: CGPoint) -> HomeTab? {
        if let hit = tabFrames.first(where: { $0.value.contains(point) })?.key {
            return hit
        }
        return tabFrames.min { abs($0.value.midX - point.x) < abs($1.value.midX - point.x) }?.key
    }

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
            // The pill's own position has its own snappier `.animation`
            // modifier above, which takes precedence over this for that
            // specific value — this easeOut is what actually animates
            // MainTabView's screen swap (Feed/Likes/Profile/...).
            withAnimation(.easeOut(duration: 0.15)) {
                selected = tab
            }
        }
    }
}

/// Picks the right icon for the current state: custom "active" asset if
/// active + present, custom base asset if present, else SF Symbol fallback.
private struct TabIcon: View {
    let tab: HomeTab
    let isActive: Bool

    var body: some View {
        let assetName = isActive ? tab.iconNameActive : tab.iconName

        Group {
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
            } else if UIImage(named: tab.iconName) != nil {
                // Active variant not exported yet — keep the base look but
                // with the active color/weight, rather than nothing.
                Image(tab.iconName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
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

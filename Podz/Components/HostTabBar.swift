import SwiftUI

enum HostTab: String, CaseIterable {
    case tasks = "Tasks"
    case guests = "Guests"
    case pods = "My Pods"
    case mailbox = "Mailbox"
    case profile = "Profile"

    /// Plain SF Symbol fallback for every tab — the only option for
    /// Tasks/Guests, which have no export of their own yet, and the
    /// `TabBarIcon` fallback for Mailbox/My Pods if their shared assets
    /// below are ever missing.
    var systemFallback: String {
        switch self {
        case .tasks: "checklist"
        case .guests: "person.2"
        case .pods: "house"
        case .mailbox: "envelope"
        case .profile: "" // uses AvatarView instead, same as HomeTab.profile
        }
    }

    /// Reuses the exact same Figma-exported icons the hiker shell's own
    /// Mailbox/Pods tabs use (`HomeTab.iconName`) — Mailbox is genuinely
    /// the same inbox either way (see `HostTabView`), and My Pods is the
    /// same underlying concept as the hiker side's Pods tab, so both
    /// should read as the same glyph rather than a different, generic
    /// system one. `nil` for Tasks/Guests, which have no export yet.
    var assetName: String? {
        switch self {
        case .mailbox: "mailbox"
        case .pods: "pods"
        case .tasks, .guests, .profile: nil
        }
    }

    var activeAssetName: String? {
        assetName.map { "\($0)-active" }
    }
}

/// The host dashboard's own floating tab bar. Five tabs now (Tasks,
/// Guests, My Pods, Mailbox, Profile) instead of the original four —
/// Mailbox is shared with the hiker shell's own inbox, and Tasks takes
/// the spot the old placeholder "Data" tab held (see `HostTabView`).
///
/// Selection is a plain tap, same simplification `BottomTabBar` made —
/// the original version of this bar copied that file's whole
/// press-and-drag-across-tabs mechanic (hold thresholds, settle timers,
/// per-tab frame hit-testing) just to give this 5-tab layout the same
/// feel; it's the same amount of code for a fifth of the value, since a
/// host dashboard isn't tapped between tabs anywhere near as often as
/// the main feed. Profile's long press (`ModeSwitchPill`) is still
/// genuinely shared behavior worth a second copy of, so that one comes
/// from the same `ModeSwitchPill`/`ProfileLongPress` types `BottomTabBar`
/// uses rather than a third bespoke version.
struct HostTabBar: View {
    @Binding var selected: HostTab
    var profileImageName: String? = nil
    @ObservedObject private var appMode = AppModeStore.shared
    /// Picks which of `pods-badge`/`pods-badge-active`/`pods-badge-dark`
    /// to render — see `profileBadgeAssetName` below.
    @Environment(\.colorScheme) private var colorScheme

    @State private var tabFrames: [HostTab: CGRect] = [:]
    @State private var isModeSwitchRevealed = false
    @State private var modeSwitchProgress: CGFloat = 0
    /// See `BottomTabBar`'s identical `modeSwitchPillHeight` — measured so
    /// the pill's own offset lands an exact 10pt gap above this bar
    /// regardless of the pill's actual rendered height.
    @State private var modeSwitchPillHeight: CGFloat = 56
    /// Same race-free suppression as `BottomTabBar`'s own — see that
    /// type's doc comment on its own `suppressNextProfileTap`.
    @State private var suppressNextProfileTap = false

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    tabRow
                        .glassEffect(.regular.tint(.white.opacity(0.4)), in: .capsule)
                }
            } else {
                tabRow
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().fill(Color.white.opacity(0.4)))
                    )
            }
        }
        .overlay(
            Capsule()
                .strokeBorder(Color.appBorder, lineWidth: 0.5)
        )
        .overlay(alignment: .top) {
            if isModeSwitchRevealed {
                ModeSwitchPill(
                    label: appMode.mode == .host ? "Switch to hiker mode ?" : "Switch to hosting mode ?",
                    progress: $modeSwitchProgress,
                    onCommit: commitModeSwitch,
                    // Instant, not the animated spring — see
                    // `BottomTabBar`'s identical wiring/reasoning.
                    onCancel: dismissModeSwitchInstantly
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { modeSwitchPillHeight = $0 }
                .offset(y: -(modeSwitchPillHeight + 10))
                // See `BottomTabBar`'s identical structure for why this
                // is a `.background`, not a `ZStack` sibling.
                .background(ModeSwitchDismissCatcher(onDismiss: dismissModeSwitchInstantly))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(1)
            }
        }
    }

    private var tabRow: some View {
        HStack(spacing: 20) {
            ForEach(HostTab.allCases, id: \.self) { tab in
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
    private func tabContent(_ tab: HostTab) -> some View {
        let isHighlighted = tab == selected

        Group {
            if tab == .profile {
                AvatarView(imageName: profileImageName, size: 26)
                    .overlay(
                        Circle().strokeBorder(Color.black, lineWidth: isHighlighted ? 1.5 : 0)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        // Marks this Profile tab as the *host's* own —
                        // always shown, not gated behind any unread/new
                        // state like `BottomTabBar`'s own top-trailing
                        // dot. `Image` can't selectively re-tint one
                        // color out of a multi-color asset the way
                        // `.foregroundColor` does for the single-tint
                        // icons above, so its lighter fill/stroke are
                        // baked directly into three separate SVGs
                        // instead — one per background it can actually
                        // sit on (see `profileBadgeAssetName`).
                        Image(profileBadgeAssetName(isActive: isHighlighted))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .offset(x: 5)
                    }
                    .scaleEffect(isHighlighted ? 1.08 : 1)
            } else {
                TabBarIcon(
                    assetName: tab.assetName,
                    activeAssetName: tab.activeAssetName,
                    systemFallback: tab.systemFallback,
                    isActive: isHighlighted
                )
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isHighlighted ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { commitSelection(tab) }
    }

    private var pill: some View {
        Capsule().fill(Color.gray.opacity(0.16))
    }

    private let pillSpring: Animation = .spring(response: 0.28, dampingFraction: 0.85)
    private let tabRowVerticalPadding: CGFloat = 13
    private let pillGrowthX: CGFloat = 18
    private let pillGrowthY: CGFloat = 6

    /// `pods-badge`'s lighter fill/stroke are baked flat into three
    /// separate SVGs, one per background it can actually sit on: plain
    /// glass (`pods-badge`), the selected-tab pill layered on top of
    /// that same glass (`pods-badge-active`), and dark mode
    /// (`pods-badge-dark`, same regardless of selection — the pill's own
    /// gray tint barely shifts against `appHomeBackground`'s dark value,
    /// not enough to justify a fourth asset).
    private func profileBadgeAssetName(isActive: Bool) -> String {
        if colorScheme == .dark { return "pods-badge-dark" }
        return isActive ? "pods-badge-active" : "pods-badge"
    }

    private func handleTap(_ tab: HostTab) {
        if tab == .profile && suppressNextProfileTap {
            suppressNextProfileTap = false
            return
        }
        commitSelection(tab)
    }

    private func commitSelection(_ tab: HostTab) {
        guard tab != selected else { return }
        withAnimation(.easeOut(duration: AppMotion.quick)) {
            selected = tab
        }
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
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.appHomeBackground.ignoresSafeArea()
        HostTabBar(selected: .constant(.pods))
            .padding(.horizontal, 24)
    }
}

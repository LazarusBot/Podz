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

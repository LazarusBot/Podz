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
/// scroll content, 24pt from the bottom.
///
/// Uses real iOS 26 Liquid Glass (`.glassEffect`) to match Figma's
/// near-transparent `rgba(0,0,0,0.1)` background — the frosted look comes
/// from the system material sampling the content underneath, not from a
/// solid tint, so don't be tempted to swap the tint for something opaque.
struct BottomTabBar: View {
    @Binding var selected: HomeTab
    var profileImageName: String? = nil
    @ObservedObject private var likesStore = LikesStore.shared

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    tabRow
                        .glassEffect(.regular.tint(.black.opacity(0.2)), in: .capsule)
                }
            } else {
                // Pre-iOS 26 fallback: closest approximation with materials.
                tabRow
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().fill(Color.black.opacity(0.2)))
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
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                let isActive = selected == tab

                Button {
                    if isActive {
                        // Re-tapping the already-active tab doesn't
                        // change `selected` (same value in, same value
                        // out — no onChange to hook), so Feed's "go back
                        // to root" reset needs its own explicit signal
                        // instead of piggybacking on the tab switch.
                        if tab == .feed {
                            HomeSearchState.shared.feedReselected += 1
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selected = tab
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        if tab == .profile {
                            AvatarView(imageName: profileImageName, size: 24)
                                .overlay(
                                    Circle().strokeBorder(Color.white, lineWidth: isActive ? 1.5 : 0)
                                )
                                .scaleEffect(isActive ? 1.08 : 1)
                        } else {
                            TabIcon(tab: tab, isActive: isActive)
                                // Anchored to the icon's own bounds, not
                                // the tab's full flexible-width button —
                                // that button spans a fifth of the bar's
                                // width, so .topTrailing on it landed the
                                // badge well past the actual heart icon
                                // instead of right over it.
                                .overlay(alignment: .topTrailing) {
                                    // Transient "+1", not a persistent
                                    // count — a "that just happened"
                                    // confirmation for a like added
                                    // elsewhere (Home), not a running
                                    // unread-style badge, so it
                                    // self-clears rather than sticking
                                    // around like a notification count.
                                    if tab == .likes && likesStore.showRecentLikeBadge {
                                        // .appTextMuted, not the tab
                                        // bar's own inactive-icon gray
                                        // (.white.opacity(0.55)) — that's
                                        // white-based and reads as
                                        // practically invisible against
                                        // this white pill. This is the
                                        // app's actual gray-text token
                                        // instead (used for "Good
                                        // morning," etc.), which stays
                                        // legible here.
                                        Text("+1")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.appTextMuted)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.white))
                                            .offset(x: 12, y: -6)
                                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                                    }
                                }
                        }

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: isActive ? .bold : .medium))
                            .foregroundColor(isActive ? .white : .white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
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
        .frame(width: 24, height: 24)
        .foregroundColor(isActive ? .white : .white.opacity(0.55))
        .scaleEffect(isActive ? 1.08 : 1)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.appHomeBackground.ignoresSafeArea()
        BottomTabBar(selected: .constant(.feed))
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
    }
}

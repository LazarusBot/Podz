import SwiftUI

/// The host dashboard's own shell — parallel to `MainTabView`, shown
/// instead of it when `AppModeStore.shared.mode == .host` (see
/// `OnboardingView`'s routing). Same visual language (colors, fonts,
/// floating glass tab bar) as the hiker shell, different content: pods
/// you manage, not pods you browse.
///
/// `MyPodsView` and `ProfileView` are reused as-is — both already take
/// an optional `onBack`, the same duality `MainTabView` already relies
/// on to use `ProfileView` as a root tab (no back button) while also
/// pushing it as a sub-screen elsewhere. `Guests` (`HostGuestsView`) is
/// real now — every reservation against this host's pods, read-only.
/// `Mailbox` reuses the exact same `MailboxView` the hiker shell shows —
/// one inbox regardless of which mode you're viewing it from, not a
/// separate host-side copy. `Tasks` is the one real gap left (replaces
/// the old placeholder "Data" tab) — `FeaturePlaceholderView` rather
/// than a screen pretending to show real reservations/to-dos before
/// there's a data model behind either.
struct HostTabView: View {
    @StateObject private var auth = AuthManager.shared
    // Starts on My Pods, not Tasks, even though Tasks is first in the
    // tab order now — Tasks has no real content behind it yet
    // (FeaturePlaceholderView below), and landing a host there the
    // instant they switch modes would make the switch itself feel like
    // it went nowhere.
    @State private var selectedTab: HostTab = .pods

    /// Distance from the bar's bottom edge to the true screen edge —
    /// same value and reasoning as `MainTabView`'s own `barBottomGap`.
    private let barBottomGap: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .tasks:
                        FeaturePlaceholderView(title: "Tasks", systemImage: "checklist")
                    case .guests:
                        HostGuestsView()
                    case .pods:
                        MyPodsView()
                    case .mailbox:
                        MailboxView()
                    case .profile:
                        ProfileView()
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                HostTabBar(selected: $selectedTab, profileImageName: auth.profile?.avatarURL)
                    .padding(.horizontal, 24)
                    // Same `.offset`-from-safe-area trick as MainTabView's
                    // bar — a plain `.padding(.bottom, _)` gets silently
                    // clamped to the system's own ~34pt home-indicator
                    // inset by the Liquid Glass capsule at layout time;
                    // `.offset` is a post-layout shift, not subject to
                    // that.
                    .offset(y: proxy.safeAreaInsets.bottom - barBottomGap)
            }
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
    }
}

#Preview {
    HostTabView()
}

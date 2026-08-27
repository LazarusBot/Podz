import SwiftUI

struct MainTabView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var lenny = LennySearchViewModel.shared
    @StateObject private var homeSearch = HomeSearchState.shared
    @StateObject private var scrollState = ScrollTrackingState.shared
    @StateObject private var tabBarVisibility = TabBarVisibilityState.shared
    // Loaded here, not just from MailboxView's own `.task` — the tab
    // bar's unread badge needs to be accurate from the moment the app
    // opens, not only after the user has visited Mailbox at least once
    // this session.
    @StateObject private var messagesStore = MessagesStore.shared
    @State private var selectedTab: HomeTab = .feed

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .feed:
                    HomeView()
                case .profile:
                    ProfileView()
                case .likes:
                    LikesView()
                case .mailbox:
                    MailboxView()
                case .pods:
                    ComingSoonView(tab: selectedTab)
                }
            }
            .ignoresSafeArea(edges: .bottom)

            if lenny.phase != .editing && !homeSearch.isExpanded && !tabBarVisibility.isHidden {
                BottomTabBar(selected: $selectedTab, profileImageName: auth.profile?.avatarURL)
                    // 24, not 18 — matches this app's actual spacing
                    // system (24pt is the standard content margin
                    // everywhere else: ProfileTopBar, every screen
                    // header, etc.) instead of an unrelated leftover
                    // value, so the bar's edges now line up with the
                    // margins above it rather than sitting 6pt off.
                    .padding(.horizontal, 24)
                    // No added bottom margin — 6pt and 12pt were both
                    // tried and read as no different from the safe-area
                    // inset alone, so the bar just sits at that inset
                    // with nothing extra on top of it.
                    // Bottom-anchored, not the default center — shrinking
                    // toward its own center would pull it upward off the
                    // bottom edge as it scales down instead of settling
                    // into it.
                    .scaleEffect(scrollState.isScrollingDown ? 0.85 : 1, anchor: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: lenny.phase)
        .animation(.easeOut(duration: 0.2), value: homeSearch.isExpanded)
        .animation(.easeOut(duration: 0.2), value: scrollState.isScrollingDown)
        .animation(.easeOut(duration: 0.2), value: tabBarVisibility.isHidden)
        .background(Color.appHomeBackground.ignoresSafeArea())
        .task {
            await messagesStore.fetchAll()
            messagesStore.startRealtimeIfNeeded()
        }
    }
}

/// Placeholder for tabs whose screens haven't been built from Figma yet.
private struct ComingSoonView: View {
    let tab: HomeTab
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: tab.iconName.isEmpty ? "sparkles" : tab.iconName)
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("\(tab.rawValue) — coming soon")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
            Spacer()
            Color.clear.frame(height: 100)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appHomeBackground)
    }
}

#Preview {
    MainTabView()
}

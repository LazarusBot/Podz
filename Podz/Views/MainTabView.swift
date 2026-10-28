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
    // Same reasoning — the Profile tab's activity dot needs real data
    // from launch, not only after HomeView's own fetch (or a Profile
    // visit) happens to run first.
    @StateObject private var postsStore = PostsStore.shared
    @State private var selectedTab: HomeTab = .feed

    /// Distance from the bar's bottom edge to the true screen edge —
    /// not from the system's own ~34pt home-indicator safe area.
    private let barBottomGap: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .feed:
                        MinimalHomeView()
                    case .profile:
                        ProfileView()
                    case .likes:
                        LikesView()
                    case .mailbox:
                        MailboxView()
                    case .pods:
                        PodsView()
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                if lenny.phase != .editing && !homeSearch.isExpanded && !tabBarVisibility.isHidden {
                    MinimalTabBar(selected: $selectedTab)
                        // 24, not 18 — matches this app's actual spacing
                        // system (24pt is the standard content margin
                        // everywhere else: ProfileTopBar, every screen
                        // header, etc.) instead of an unrelated leftover
                        // value, so the bar's edges now line up with the
                        // margins above it rather than sitting 6pt off.
                        .padding(.horizontal, 24)
                        // A plain `.padding(.bottom, _).ignoresSafeArea(_)`
                        // here got silently clamped back to roughly the
                        // system's own ~34pt home-indicator inset for any
                        // modest value (0, 6, and 12 all landed in the
                        // same spot; only an oversized 150 visibly moved
                        // it) — the Liquid Glass capsule (`.glassEffect`)
                        // appears to enforce its own minimum clearance
                        // from the true edge at layout time, so asking it
                        // to sit *closer* than that gets ignored.
                        // `.offset` is a pure post-layout pixel shift
                        // rather than a layout-time frame proposal, so
                        // it isn't subject to that clamping — it reliably
                        // lands wherever asked, hence computing the shift
                        // from the real safe-area inset (via this
                        // GeometryReader) instead.
                        .offset(y: proxy.safeAreaInsets.bottom - barBottomGap)
                        // Bottom-anchored, not the default center — shrinking
                        // toward its own center would pull it upward off the
                        // bottom edge as it scales down instead of settling
                        // into it.
                        .scaleEffect(scrollState.isScrollingDown ? 0.85 : 1, anchor: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: AppMotion.snappy), value: lenny.phase)
        .animation(.easeOut(duration: AppMotion.snappy), value: homeSearch.isExpanded)
        .animation(.easeOut(duration: AppMotion.snappy), value: scrollState.isScrollingDown)
        .animation(.easeOut(duration: AppMotion.snappy), value: tabBarVisibility.isHidden)
        .background(Color.appHomeBackground.ignoresSafeArea())
        // Home follows the system appearance; the other tabs have no dark
        // palette yet, so they (and the tab bar over them) stay light.
        .preferredColorScheme(selectedTab == .feed ? nil : .light)
        .task {
            await messagesStore.fetchAll()
            messagesStore.startRealtimeIfNeeded()
        }
        .task { await postsStore.fetchFeed() }
    }
}

#Preview {
    MainTabView()
}

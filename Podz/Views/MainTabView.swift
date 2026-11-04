import SwiftUI

struct MainTabView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var scrollState = ScrollTrackingState.shared
    @StateObject private var tabBarVisibility = TabBarVisibilityState.shared
    @StateObject private var appearance = AppearanceState.shared
    @State private var selectedTab: TravelerTab = .feed
    @StateObject private var tabRouter = TabRouter.shared
    @StateObject private var contactTracker = HutContactTracker.shared
    // Watched only to keep the huts you need offline up to date.
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var reservationsStore = ReservationsStore.shared
    @StateObject private var podsStore = PodsStore.shared
    @Environment(\.scenePhase) private var scenePhase

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
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                if !tabBarVisibility.isHidden {
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
        .animation(.easeOut(duration: AppMotion.snappy), value: scrollState.isScrollingDown)
        .animation(.easeOut(duration: AppMotion.snappy), value: tabBarVisibility.isHidden)
        .background(Color.appHomeBackground.ignoresSafeArea())
        // Home and Likes follow the system appearance; the other tabs have
        // no dark palette yet, so they (and the tab bar over them) stay
        // light — except a screen that has opted in (Profile's main one).
        // Leaving the app to call or write to a hut, and coming back.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: contactTracker.appWentToBackground()
            case .active: contactTracker.appBecameActive()
            default: break
            }
        }
        .onAppear { contactTracker.appBecameActive() }
        // Back from a hut: Lenny asks on that hut's own page, so open it (Home,
        // the pod's detail) if it isn't already. Nothing floats over the tabs.
        .onChange(of: contactTracker.askNow) { _, asks in
            guard asks, let podId = contactTracker.pendingPodId else { return }
            selectedTab = .feed
            DeepLinkRouter.shared.pendingPodId = podId
        }
        // The huts you liked or have a stay at are kept on the phone (photos, map,
        // details) for when there's no signal; a pause first, so a burst of
        // changes is one pass.
        .task(id: "\(likesStore.likes.count)-\(reservationsStore.reservations.count)-\(podsStore.pods.count)") {
            guard !podsStore.pods.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await OfflinePackStore.shared.sync()
        }
        // Keep the passes on the phone fresh, so they open with no signal.
        .task { await TripPassStore.shared.refreshFromServer() }
        // Something (Lenny's plan) asked Profile to open a page.
        .onChange(of: tabRouter.showsReservationsRequested) { _, requested in
            if requested { selectedTab = .profile }
        }
        // The empty Reservations page asked for Lenny: Home, search open.
        .onChange(of: tabRouter.lennyRequested) { _, requested in
            if requested { selectedTab = .feed }
        }
        // An empty Likes folder asked for Home, to find huts to add.
        .onChange(of: tabRouter.homeRequested) { _, requested in
            guard requested else { return }
            selectedTab = .feed
            tabRouter.homeRequested = false
        }
        .preferredColorScheme(selectedTab == .feed || selectedTab == .likes || appearance.followsSystem ? nil : .light)
    }
}

#Preview {
    MainTabView()
}

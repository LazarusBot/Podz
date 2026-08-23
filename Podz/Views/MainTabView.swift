import SwiftUI

struct MainTabView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var lenny = LennySearchViewModel.shared
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
                case .pods, .mailbox:
                    ComingSoonView(tab: selectedTab)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            
            if lenny.phase != .editing {
                BottomTabBar(selected: $selectedTab, profileImageName: auth.profile?.avatarURL)
                    .padding(.horizontal, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: lenny.phase)
        .background(Color.appHomeBackground.ignoresSafeArea())
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

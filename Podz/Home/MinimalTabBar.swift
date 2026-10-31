import SwiftUI

/// The traveler's three tabs.
enum TravelerTab: String, CaseIterable {
    case feed = "Home"
    case likes = "Likes"
    case profile = "Profile"
}

/// The floating three-icon pill from the Paper Home frame — home, likes,
/// profile. Flat grey capsule, thin line icons, the active one full
/// strength and the others dimmed.
struct MinimalTabBar: View {
    @Binding var selected: TravelerTab

    private static let tabs = TravelerTab.allCases

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.tabs, id: \.self) { tab in
                Button {
                    if tab == selected, tab == .feed {
                        HomeSearchState.shared.feedReselected += 1
                    }
                    selected = tab
                } label: {
                    tabIcon(tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(tab == selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 18)
        .frame(width: 220, height: 64)
        .background(Color.homePill, in: Capsule())
        .animation(.easeOut(duration: AppMotion.snappy), value: selected)
    }

    private static let iconStyle = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)

    private func tabIcon(_ tab: TravelerTab) -> some View {
        let isSelected = tab == selected
        return icon(for: tab)
            .stroke(Color.homeText, style: Self.iconStyle)
            .frame(width: 22, height: 22)
            .opacity(isSelected ? 1 : 0.45)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }

    private func icon(for tab: TravelerTab) -> AnyShape {
        switch tab {
        case .feed: AnyShape(HomeIconShape())
        case .likes: AnyShape(HeartIconShape())
        case .profile: AnyShape(ProfileIconShape())
        }
    }
}

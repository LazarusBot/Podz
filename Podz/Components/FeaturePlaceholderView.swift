import SwiftUI

/// Generic "not built yet" placeholder for a tab — same idea as
/// `MainTabView`'s own private `ComingSoonView` (that one's tied
/// specifically to `HomeTab`, so a different name here rather than
/// risking confusion with it), used by `HostTabView`'s Guests/Data tabs
/// until those have real screens behind them.
struct FeaturePlaceholderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("\(title) — coming soon")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
            Spacer()
            Color.clear.frame(height: 100)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appHomeBackground)
    }
}

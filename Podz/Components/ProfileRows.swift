import SwiftUI

/// A row on the screens Profile opens (login and security, accessibility…):
/// the same flat list row as Profile's own, see `ProfileListRow`. `icon` is
/// kept so existing call sites still compile; the design has no row icons.
struct ProfileMenuRow: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    var badgeCount: Int? = nil
    /// Defaults to `!isDestructive`; pass `false` for a row that acts right
    /// here (e.g. "Send password reset email") instead of opening a screen.
    var showsChevron: Bool? = nil
    var onTap: () -> Void = {}

    var body: some View {
        ProfileListRow(
            title: title,
            badgeCount: badgeCount,
            isDestructive: isDestructive,
            showsChevron: showsChevron,
            action: onTap
        )
    }
}

/// Quiet, uppercase small-caps label above a group of rows — standard
/// iOS Settings weight. Shared by ProfileView (Social / Account / Danger
/// zone) and FriendsView (Requests / Accepted friends), which previously
/// had two different section-header styles (this quiet one vs. a bold
/// 18pt Darker Grotesque one) one tap apart in the same navigation flow.
struct SectionLabel: View {
    let title: String
    /// Optional right-aligned text on the same row as the title — e.g.
    /// ProfileView's mountain-height gag culminating in its Danger zone
    /// section. `nil` for every other call site (Requests, Accepted
    /// friends…), which keeps just the title.
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                // Real Inter, Regular weight — see `ProfileAccountRow`'s
                // own subtitle for why this isn't `AppFont.itemTitle`
                // (Bold read heavier than this quiet section label
                // wants; the uppercase + tracking already gives it
                // enough presence).
                .font(AppFont.regularLabel(12))
                .tracking(0.5)
                .foregroundColor(.appTextMuted)

            if let trailing {
                Spacer()
                Text(trailing)
                    .font(AppFont.regularLabel(12))
                    .tracking(0.5)
                    .foregroundColor(.appTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }
}

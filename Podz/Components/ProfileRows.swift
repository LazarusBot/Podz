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

/// A quiet label above a group of rows, optionally with a right-aligned
/// note (used by the host Pods screen). The screens Profile opens use
/// `SectionHeading`.
struct SectionLabel: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)

            if let trailing {
                Spacer()
                Text(trailing)
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }
}

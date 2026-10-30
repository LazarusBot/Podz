import SwiftUI

/// One row of the Profile list: a plain label, a quiet chevron when it goes
/// somewhere, a hairline under it. No icons, no card.
struct ProfileListRow: View {
    let title: String
    /// Unseen activity, shown as a small count. Nil or 0 hides it.
    var badgeCount: Int? = nil
    /// The label turns red (log out, delete account) and the chevron goes.
    var isDestructive = false
    /// Rows that act right here instead of opening a screen have no chevron.
    var showsChevron: Bool? = nil
    /// A quiet note at the trailing end, e.g. "Coming soon".
    var caption: String? = nil
    /// Greyed out and not tappable.
    var isDisabled = false
    var action: () -> Void

    private var hasChevron: Bool { showsChevron ?? !isDestructive }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(AppFont.regularLabel(16))
                    .foregroundColor(isDestructive ? .appBadgeRed : .homeText)

                Spacer()

                if let caption {
                    Text(caption)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                }

                if let badgeCount, badgeCount > 0 {
                    Text(badgeCount > 9 ? "9+" : "\(badgeCount)")
                        .font(AppFont.semiBoldLabel(12))
                        .foregroundColor(.homeText)
                        .frame(minWidth: 22, minHeight: 22)
                        .padding(.horizontal, 2)
                        .background(Capsule().fill(Color.homePill))
                }

                if hasChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.homeSubtitle)
                }
            }
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.homeText.opacity(0.08)).frame(height: 0.5)
        }
        .padding(.horizontal, 24)
    }
}

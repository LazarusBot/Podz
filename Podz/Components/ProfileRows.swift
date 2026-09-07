import SwiftUI

/// "Boso / Show profile" row with avatar (node 3827:1387).
/// Padding: 24 horizontal / 31 vertical, gap 15 between avatar and text,
/// hairline border-bottom at 0.5px — exact Figma values, don't round.
struct ProfileAccountRow<AvatarContent: View>: View {
    let name: String
    var subtitle: String = "Show profile"
    var avatarImageName: String? = nil
    @ViewBuilder var avatarContent: () -> AvatarContent
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                avatarContent()

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(AppFont.pillLabelSemiBold(16))
                        .foregroundColor(.black)
                    Text(subtitle)
                        // Real Inter, Regular weight — not
                        // `AppFont.mediumLabel` (fixed elsewhere to
                        // unbreak `ModeSwitchPill`'s label, which
                        // genuinely needed distinct weights; Inter
                        // Medium reads heavier than this row wants) and
                        // not the system font either. See
                        // `AppFont.regularLabel`.
                        .font(AppFont.regularLabel(11))
                        .foregroundColor(.appTextMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
            }
            // Without this, `Button` only registers taps on the HStack's
            // actual rendered content (avatar, text, chevron) — the
            // `Spacer()`'s own empty space in between reports no hit
            // area by default, so tapping the middle of the row (where
            // there's nothing drawn) silently did nothing.
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 31)
        .background(Color.appHomeBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
        }
    }
}

/// Convenience initializer — keeps every existing call site
/// (`ProfileAccountRow(name:..., avatarImageName:...) { }`) working
/// unchanged, using a plain AvatarView when no custom avatar view is given.
extension ProfileAccountRow where AvatarContent == AvatarView {
    init(
        name: String,
        subtitle: String = "Show profile",
        avatarImageName: String? = nil,
        avatarCornerRadius: CGFloat? = nil,
        onTap: @escaping () -> Void = {}
    ) {
        self.name = name
        self.subtitle = subtitle
        self.avatarImageName = avatarImageName
        self.avatarContent = { AvatarView(imageName: avatarImageName, size: 42, cornerRadius: avatarCornerRadius) }
        self.onTap = onTap
    }
}

/// Generic settings row: icon + label + trailing chevron
/// (node pattern repeated for Personal information / Payments and
/// payouts / Login and security / Accessibility, 3827:1402 etc).
/// Padding: 24 horizontal / 18 vertical, gap 11 between icon and label —
/// distinct from ProfileAccountRow's 31pt vertical padding, keep exact.
struct ProfileMenuRow: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    /// Nil or 0 hides the pill entirely — a badge reading "0" would read
    /// as "there's something, but it's nothing," which is worse than no
    /// badge at all.
    var badgeCount: Int? = nil
    /// Defaults to `!isDestructive` (every non-destructive row used to
    /// always show one) — override to `false` for a row that performs an
    /// action right here (e.g. LoginSecurityView's "Send password reset
    /// email") rather than navigating to another screen. The chevron
    /// promises "this goes somewhere else"; showing it on an action row
    /// was a leftover inconsistency, not a deliberate choice.
    var showsChevron: Bool? = nil
    var onTap: () -> Void = {}

    private var tint: Color { isDestructive ? .red : .black }
    private var resolvedShowsChevron: Bool { showsChevron ?? !isDestructive }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 17)

                Text(title)
                    // Real Inter, Regular weight — see
                    // `ProfileAccountRow`'s own subtitle for why.
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(tint)

                Spacer()

                if let badgeCount, badgeCount > 0 {
                    // Same shape/weight as BottomTabBar's own Mailbox
                    // unread pill — one shared "new activity" style
                    // across the app, not a one-off for this row.
                    Text(badgeCount > 9 ? "9+" : "\(badgeCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .frame(minWidth: 20)
                        .background(Capsule().fill(Color.appMessageBlue))
                }

                if resolvedShowsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            // Same missing-hit-area issue as `ProfileAccountRow` — see
            // its own comment.
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.appHomeBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
        }
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

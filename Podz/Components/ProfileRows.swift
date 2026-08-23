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
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.appTextMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
            }
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
        onTap: @escaping () -> Void = {}
    ) {
        self.name = name
        self.subtitle = subtitle
        self.avatarImageName = avatarImageName
        self.avatarContent = { AvatarView(imageName: avatarImageName, size: 42) }
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
    var onTap: () -> Void = {}

    private var tint: Color { isDestructive ? .red : .black }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(tint)
                    .frame(width: 17)

                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(tint)

                Spacer()

                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.appHomeBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
        }
    }
}

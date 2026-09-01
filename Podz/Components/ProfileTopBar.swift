import SwiftUI

/// Header row: back button (44x44 circle, Apple's HIG minimum tap target —
/// Figma's node 3827:1382 spec was 31x31) — centered title — empty
/// trailing spacer. Padding is 24 horizontal / 31 vertical exactly as in
/// Figma — don't round these to 20/32.
struct ProfileTopBar: View {
    var title: String = "Profile"
    var onBack: (() -> Void)? = nil
    /// Optional trailing action (e.g. LikesView's "Share this folder") —
    /// replaces the empty symmetry placeholder when provided, still the
    /// same 44x44 so the title stays centered either way.
    var trailingIcon: String? = nil
    var onTrailingTap: (() -> Void)? = nil
    /// Small unseen-activity dot on the trailing icon (e.g. MyPostsView's
    /// bell) — same plain-dot style as BottomTabBar's Profile tab, not a
    /// count, since the real number already shows elsewhere (the "Posts"
    /// row's badge, or whatever screen this leads to).
    var trailingBadge: Bool = false

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                }
                .background(Circle().fill(Color.white))
                .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            Spacer()

            Text(title)
                .font(AppFont.pillLabel(24))
                .fontWeight(.heavy)
                .foregroundColor(.black)

            Spacer()

            if let trailingIcon, let onTrailingTap {
                Button(action: onTrailingTap) {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                }
                .background(Circle().fill(Color.white))
                .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
                .overlay(alignment: .topTrailing) {
                    if trailingBadge {
                        // No extra offset — aligning this 12pt badge's own
                        // corner to the 44pt button's corner already lands
                        // its center right at the button's circular edge
                        // (44pt box corner sits ~22.6pt from center, same
                        // as the button's own 22pt radius), so it straddles
                        // the stroke instead of floating past it or
                        // sitting deep inside.
                        Circle()
                            .fill(Color.appMessageBlue)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    }
                }
            } else {
                // Empty placeholder to keep the title perfectly centered
                // (matches the empty circle on the right in Figma, node 3827:1386).
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 31)
        .background(Color.appHomeBackground)
    }
}

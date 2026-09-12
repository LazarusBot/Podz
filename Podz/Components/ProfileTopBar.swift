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
    /// What the trailing icon does (e.g. "Share folder", "Delete post") —
    /// the icon alone has nothing else to announce to VoiceOver.
    var trailingAccessibilityLabel: String = "More"
    /// Small unseen-activity dot on the trailing icon (e.g. MyPostsView's
    /// bell) — same plain-dot style as BottomTabBar's Profile tab, not a
    /// count, since the real number already shows elsewhere (the "Posts"
    /// row's badge, or whatever screen this leads to).
    var trailingBadge: Bool = false
    /// Skips the opaque `appHomeBackground` fill — e.g. ProfileEditView's
    /// own header, floating this bar's back/edit buttons over a photo
    /// instead of a flat colored bar. Also switches the buttons themselves
    /// from solid white circles to real Liquid Glass with a white stroke —
    /// a solid white circle reads fine on a flat background, but over
    /// varied photo content it looks like an odd opaque patch rather than
    /// a floating control.
    var transparentBackground: Bool = false

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                }
                .modifier(TopBarButtonChrome(transparentBackground: transparentBackground))
                .accessibilityLabel("Back")
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
                .modifier(TopBarButtonChrome(transparentBackground: transparentBackground))
                .accessibilityLabel(trailingAccessibilityLabel)
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
        .background(transparentBackground ? Color.clear : Color.appHomeBackground)
    }
}

/// Solid white circle everywhere this bar had it before, or real Liquid
/// Glass — with its own dynamic specular highlight, not just a blur —
/// over `transparentBackground`'s photo. Same recipe as `AvatarPicker`'s
/// own `CameraBadge`, so a floating circle button reads the same wherever
/// it shows up in the app, with the same iOS 26 availability gate and
/// `.ultraThinMaterial` fallback below it.
private struct TopBarButtonChrome: ViewModifier {
    let transparentBackground: Bool

    func body(content: Content) -> some View {
        if transparentBackground {
            Group {
                if #available(iOS 26, *) {
                    GlassEffectContainer {
                        content.glassEffect(.regular.tint(.white.opacity(0.1)), in: .circle)
                    }
                } else {
                    content.background(Circle().fill(.ultraThinMaterial))
                }
            }
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 1))
        } else {
            content
                .background(Circle().fill(Color.white))
                .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
        }
    }
}

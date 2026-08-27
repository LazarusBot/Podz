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

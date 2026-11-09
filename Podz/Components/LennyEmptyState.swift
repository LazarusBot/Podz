import SwiftUI

/// Lenny's mark in a `homeText` disc: his avatar wherever he speaks outside a
/// bubble.
struct LennyAvatar: View {
    var size: CGFloat = 30
    var accessory: LennyAccessory? = nil

    var body: some View {
        LennyDisc(accessory: accessory)
            .frame(width: size, height: size)
    }
}

/// The one empty page: a page with nothing in it is Lenny's invitation, never
/// an illustration or a bare gray line. A 40 Lenny disc, a 20 semiBold title,
/// one 14 `homeSubtitle` line and, when the page has no pill of its own to act
/// with, a small caption (13 `homeSubtitle`, underlined, thin chevron) that
/// does the one thing there is to do.
struct LennyEmptyState: View {
    let title: String
    let line: String
    /// The caption's words and what it does; both nil when the page's own pill
    /// already acts (Plan with Lenny, Add friend).
    var caption: String? = nil
    var action: (() -> Void)? = nil
    /// What Lenny wears on this page (see `LennyAccessory`).
    var accessory: LennyAccessory? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LennyAvatar(size: 40, accessory: accessory)
                .accessibilityHidden(true)
            T(title)
                .font(AppFont.semiBoldLabel(20))
                .foregroundColor(.homeText)
            T(line)
                .font(AppFont.regularLabel(14))
                .foregroundColor(.homeSubtitle)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let caption, let action {
                Button(action: action) {
                    CaptionLabel(caption)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

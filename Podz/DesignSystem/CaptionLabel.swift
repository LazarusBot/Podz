import SwiftUI

/// The small caption every "next step" in the app is: 13 regular `homeSubtitle`,
/// underlined, with a thin chevron (`design.md`, captions). Put it in a plain
/// `Button`. `vertical` is the padding above and below the text, and `outset`
/// how far the tappable area grows past it (see `captionTapArea`).
struct CaptionLabel: View {
    let title: String
    var vertical: CGFloat = 8
    var outset: CGFloat = 8

    init(_ title: String, vertical: CGFloat = 8, outset: CGFloat = 8) {
        self.title = title
        self.vertical = vertical
        self.outset = outset
    }

    var body: some View {
        HStack(spacing: 5) {
            T(title)
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
                .underline(color: Color.homeSubtitle.opacity(0.5))
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.homeSubtitle)
        }
        .padding(.vertical, vertical)
        .captionTapArea(outset: outset)
    }
}

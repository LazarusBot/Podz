import SwiftUI

/// The photo that fans out of a Likes folder and the one that drops into it
/// while you save a like. Same shape as the folder screen's tiles (portrait
/// 166 x 216, radius 36 continuous), flat: no white border, no shadow
/// (`design.md`). `side` is the folder icon's own side, which everything on
/// the card is measured from.
struct FolderFanPhoto: View {
    let url: String?
    let side: CGFloat

    private var width: CGFloat { side * 0.5 }
    private var height: CGFloat { width * 216 / 166 }

    var body: some View {
        PodPhoto(url: url)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: width * 36 / 166, style: .continuous))
    }
}

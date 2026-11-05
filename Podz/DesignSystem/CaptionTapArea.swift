import SwiftUI

extension View {
    /// A small 13 pt caption ("Details ›", "See all") keeps its look and its
    /// place in the layout, but takes taps in a band about 44 pt tall (Apple's
    /// minimum target): the tappable shape grows by `outset` on every side
    /// without adding any space. Pass a bigger `outset` for a caption with
    /// little or no padding of its own (16 pt of text needs 14).
    func captionTapArea(outset: CGFloat = 8) -> some View {
        contentShape(Rectangle().inset(by: -outset))
    }
}

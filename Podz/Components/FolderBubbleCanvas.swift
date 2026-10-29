import SwiftUI

/// Lays folder bubbles out in the Paper zig-zag and shrinks the whole
/// composition as folders are added, so several still fit the screen:
/// one bubble is 300 across, then 88%, 76%, and down to 63%. Text and badges
/// keep their real size (`textScale`).
///
/// Positions are worked out on a virtual canvas as wide as the screen would
/// be at full size, then scaled together: bubble centers alternate between
/// 31% and 85.5% of the width, 253 apart, the first 177 below the top.
struct FolderBubbleCanvas<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let width: CGFloat
    /// Room under the last bubble, e.g. for a row of buttons.
    var bottomRoom: CGFloat = 40
    /// Builds one bubble: the item, its index, and the scale to hand to
    /// `FolderBubble.textScale`.
    @ViewBuilder var content: (Item, Int, CGFloat) -> Content

    private static var step: CGFloat { 253 }
    private static var firstCenterY: CGFloat { 177 }
    private static var minScale: CGFloat { 0.63 }

    private var scale: CGFloat { max(Self.minScale, 1 - 0.12 * CGFloat(max(items.count - 1, 0))) }

    private var virtualHeight: CGFloat {
        Self.firstCenterY + Self.step * CGFloat(max(items.count - 1, 0))
            + FolderBubble.diameter / 2 + bottomRoom / scale
    }

    var body: some View {
        let s = scale
        let virtualWidth = width / s

        ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item, index, 1 / s)
                    .position(
                        x: virtualWidth * (index % 2 == 0 ? 0.31 : 0.855),
                        y: Self.firstCenterY + Self.step * CGFloat(index)
                    )
            }
        }
        .frame(width: virtualWidth, height: virtualHeight, alignment: .topLeading)
        .scaleEffect(s, anchor: .topLeading)
        .frame(width: width, height: virtualHeight * s, alignment: .topLeading)
        .animation(.smooth(duration: 0.4), value: items.count)
    }
}

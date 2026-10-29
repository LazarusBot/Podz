import SwiftUI

/// Packs folder bubbles into a foam: compact, slightly overlapping, with flat
/// edges where they touch (see `FoamLayout`). The bubbles shrink as folders
/// are added so several still fit, and each bubble's size follows the number
/// of pods inside it. **Pinch out** to unpack them (they drift apart into
/// plain circles); **pinch in** to pack them again.
struct FolderBubbleCanvas<Item: Identifiable, Content: View>: View {
    let items: [Item]
    /// How many pods each item holds; sets its size.
    let podCount: (Item) -> Int
    let width: CGFloat
    /// Room under the last bubble, e.g. for a row of buttons.
    var bottomRoom: CGFloat = 40
    /// Builds one bubble from the item, its index and its cell.
    @ViewBuilder var content: (Item, Int, FoamCell) -> Content

    private static var topInset: CGFloat { 24 }

    /// 0 packed ... 1 unpacked. One value drives everything: it follows the
    /// fingers while pinching, then animates to 0 or 1 on release.
    @State private var looseness: CGFloat = 0
    /// Where `looseness` was when the current pinch started.
    @State private var pinchStart: CGFloat?
    /// The packing is the expensive part, so it's kept until the folders or
    /// the width change; spreading it out while pinching is cheap.
    @State private var packCache = PackCache()

    private final class PackCache {
        var key = ""
        var radii: [CGFloat] = []
        var centers: [CGPoint] = []
    }

    private var packed: (radii: [CGFloat], centers: [CGPoint]) {
        let ids = items.map { String(describing: $0.id) }
        let counts = items.map(podCount)
        let key = "\(ids)|\(counts)|\(Int(width))"
        if packCache.key != key {
            let radii = FoamLayout.radii(
                podCounts: counts,
                base: FoamLayout.baseRadius(count: items.count),
                maxRadius: width * 0.475
            )
            packCache.radii = radii
            packCache.centers = FoamLayout.pack(radii: radii, ids: ids, width: width, top: Self.topInset)
            packCache.key = key
        }
        return (packCache.radii, packCache.centers)
    }

    var body: some View {
        let packed = packed

        FoamField(
            items: items,
            radii: packed.radii,
            centers: packed.centers,
            width: width,
            topInset: Self.topInset,
            bottomRoom: bottomRoom,
            looseness: looseness,
            content: content
        )
        .contentShape(Rectangle())
        // When folders come and go or a bubble grows (not for the pinch,
        // which animates `looseness` itself).
        .animation(.smooth(duration: 0.5), value: items.map { String(describing: $0.id) })
        .animation(.smooth(duration: 0.5), value: items.map(podCount))
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let start = pinchStart ?? looseness
                    pinchStart = start
                    // Follows the fingers directly, no animation.
                    looseness = min(max(start + (value.magnification - 1) / 0.6, 0), 1)
                }
                .onEnded { _ in
                    pinchStart = nil
                    // Settles on whichever side it passed halfway, with a
                    // soft spring so it doesn't stop dead.
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        looseness = looseness > 0.5 ? 1 : 0
                    }
                }
        )
    }
}

/// The bubbles at one `looseness`. It's `Animatable`, so when `looseness`
/// is animated SwiftUI calls `body` for every in-between value: the bubbles'
/// positions *and* the flat edges where they touch change smoothly together,
/// instead of the edges popping at the start or end.
private struct FoamField<Item: Identifiable, Content: View>: View, Animatable {
    let items: [Item]
    let radii: [CGFloat]
    let centers: [CGPoint]
    let width: CGFloat
    let topInset: CGFloat
    let bottomRoom: CGFloat
    var looseness: CGFloat
    let content: (Item, Int, FoamCell) -> Content

    var animatableData: CGFloat {
        get { looseness }
        set { looseness = newValue }
    }

    var body: some View {
        let cells = FoamLayout.cells(
            centers: centers,
            radii: radii,
            width: width,
            top: topInset,
            looseness: looseness
        )
        let height = (cells.map { $0.center.y + $0.radius }.max() ?? 0) + bottomRoom

        ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item, index, cells[index])
                    .position(cells[index].center)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

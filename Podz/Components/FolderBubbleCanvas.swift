import SwiftUI

/// Packs folder bubbles into a foam: compact, slightly overlapping, with flat
/// edges where they touch (see `FoamLayout`). The bubbles shrink as folders
/// are added so several still fit, and each bubble's size follows the number
/// of pods inside it. **Pinch out** to unpack them (they drift
/// apart into plain circles); **pinch in** to pack them again.
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

    /// Whether the bubbles are unpacked. Starts packed.
    @State private var isLoose = false
    @GestureState private var pinch: CGFloat = 1
    /// The packing is the expensive part, so it's kept until the folders or
    /// the width change; spreading it out while pinching is cheap.
    @State private var packCache = PackCache()

    private final class PackCache {
        var key = ""
        var radii: [CGFloat] = []
        var centers: [CGPoint] = []
    }

    /// 0 packed ... 1 unpacked, following the fingers while pinching.
    private var looseness: CGFloat {
        if isLoose {
            return 1 - min(max((1 - pinch) / 0.4, 0), 1)
        }
        return min(max((pinch - 1) / 0.6, 0), 1)
    }

    private var cells: [FoamCell] {
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
        return FoamLayout.cells(
            centers: packCache.centers,
            radii: packCache.radii,
            width: width,
            top: Self.topInset,
            looseness: looseness
        )
    }

    var body: some View {
        let cells = cells
        let height = (cells.map { $0.center.y + $0.radius }.max() ?? 0) + bottomRoom

        ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item, index, cells[index])
                    .position(cells[index].center)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .contentShape(Rectangle())
        // Animates when folders come and go and when a pinch is released —
        // not while the fingers are moving, so the bubbles follow them.
        .animation(.smooth(duration: 0.5), value: items.map { String(describing: $0.id) })
        .animation(.smooth(duration: 0.5), value: isLoose)
        // A bubble grows as a pod is added to it.
        .animation(.smooth(duration: 0.5), value: items.map(podCount))
        .simultaneousGesture(
            MagnifyGesture()
                .updating($pinch) { value, state, _ in state = value.magnification }
                .onEnded { value in
                    let shouldLoosen = isLoose
                        ? value.magnification > 0.8
                        : value.magnification > 1.3
                    withAnimation(.smooth(duration: 0.5)) { isLoose = shouldLoosen }
                }
        )
    }
}

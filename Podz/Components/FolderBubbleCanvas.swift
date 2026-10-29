import SwiftUI

/// Packs folder bubbles into a foam: compact, slightly overlapping, with flat
/// edges where they touch (see `FoamLayout`). The bubbles shrink as folders
/// are added so several still fit, and a folder holding more pods is a bit
/// bigger than one holding fewer.
struct FolderBubbleCanvas<Item: Identifiable, Content: View>: View {
    let items: [Item]
    /// How many pods each item holds; sets its relative size.
    let podCount: (Item) -> Int
    let width: CGFloat
    /// Room under the last bubble, e.g. for a row of buttons.
    var bottomRoom: CGFloat = 40
    /// Builds one bubble from the item, its index and its cell.
    @ViewBuilder var content: (Item, Int, FoamCell) -> Content

    private static var topInset: CGFloat { 24 }

    private var cells: [FoamCell] {
        let counts = items.map(podCount)
        let radii = FoamLayout.radii(podCounts: counts, base: FoamLayout.baseRadius(count: items.count))
        return FoamLayout.cells(radii: radii, width: width, top: Self.topInset)
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
        .animation(.smooth(duration: 0.5), value: cells)
    }
}

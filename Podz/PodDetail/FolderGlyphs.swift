import SwiftUI

/// The selected tile's check, ported from the Paper "LikesFolderView" SVG
/// (12 x 10).
struct CheckGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.125, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.375, y: rect.minY + rect.height * 0.8))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.875, y: rect.minY + rect.height * 0.18))
        return path
    }
}

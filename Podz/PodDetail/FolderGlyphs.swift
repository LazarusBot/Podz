import SwiftUI

/// The two small glyphs of the Likes folder screen, ported from the Paper
/// "LikesFolderView" SVGs.

/// The share "link" glyph (SVG viewBox 0.042 0.042 1.5 x 1.5, drawn at 18pt).
struct LinkGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let origin: CGFloat = 0.042
        let scale = min(rect.width, rect.height) / 1.5
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (x - origin) * scale, y: rect.minY + (y - origin) * scale)
        }

        var path = Path()
        path.move(to: point(0.541, 1.252))
        let firstChain: [[CGFloat]] = [
            [0.53, 1.27, 0.516, 1.281, 0.505, 1.292],
            [0.445, 1.328, 0.374, 1.328, 0.313, 1.292],
            [0.291, 1.276, 0.271, 1.252, 0.228, 1.206],
            [0.185, 1.159, 0.168, 1.135, 0.157, 1.113],
            [0.123, 1.047, 0.123, 0.966, 0.157, 0.899],
            [0.168, 0.876, 0.185, 0.852, 0.228, 0.804],
        ]
        for c in firstChain {
            path.addCurve(to: point(c[4], c[5]), control1: point(c[0], c[1]), control2: point(c[2], c[3]))
        }
        path.addLine(to: point(0.41, 0.608))
        let secondChain: [[CGFloat]] = [
            [0.453, 0.56, 0.473, 0.538, 0.496, 0.522],
            [0.556, 0.483, 0.627, 0.483, 0.687, 0.522],
            [0.706, 0.538, 0.73, 0.56, 0.773, 0.608],
            [0.809, 0.649, 0.83, 0.671, 0.844, 0.703],
            [0.877, 0.763, 0.877, 0.849, 0.844, 0.915],
            [0.838, 0.925, 0.826, 0.937, 0.815, 0.958],
        ]
        for c in secondChain {
            path.addCurve(to: point(c[4], c[5]), control1: point(c[0], c[1]), control2: point(c[2], c[3]))
        }

        path.move(to: point(0.635, 0.758))
        let thirdChain: [[CGFloat]] = [
            [0.624, 0.771, 0.61, 0.787, 0.606, 0.8],
            [0.573, 0.866, 0.573, 0.947, 0.606, 1.013],
            [0.619, 1.037, 0.641, 1.059, 0.678, 1.107],
            [0.72, 1.154, 0.741, 1.173, 0.763, 1.187],
            [0.82, 1.225, 0.895, 1.225, 0.955, 1.187],
            [0.974, 1.173, 0.997, 1.154, 1.037, 1.107],
        ]
        for c in thirdChain {
            path.addCurve(to: point(c[4], c[5]), control1: point(c[0], c[1]), control2: point(c[2], c[3]))
        }
        path.addLine(to: point(1.219, 0.904))
        let fourthChain: [[CGFloat]] = [
            [1.263, 0.858, 1.279, 0.833, 1.294, 0.809],
            [1.327, 0.744, 1.327, 0.663, 1.294, 0.598],
            [1.279, 0.575, 1.263, 0.549, 1.219, 0.505],
            [1.176, 0.461, 1.156, 0.439, 1.137, 0.423],
            [1.077, 0.386, 1.002, 0.386, 0.945, 0.423],
            [0.931, 0.427, 0.92, 0.442, 0.906, 0.456],
        ]
        for c in fourthChain {
            path.addCurve(to: point(c[4], c[5]), control1: point(c[0], c[1]), control2: point(c[2], c[3]))
        }
        return path
    }
}

/// The selected tile's check (SVG 12 x 10).
struct CheckGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.125, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.375, y: rect.minY + rect.height * 0.8))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.875, y: rect.minY + rect.height * 0.18))
        return path
    }
}

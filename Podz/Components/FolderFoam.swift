import SwiftUI

/// One bubble of the Likes foam: where it sits, how big it is, and the flat
/// cuts where its neighbors press into it (like soap bubbles that touch).
struct FoamCell: Equatable {
    /// A straight cut: everything beyond `distance` along `direction` (a
    /// unit vector from this bubble's center) is trimmed away.
    struct Cut: Equatable {
        var direction: CGVector
        var distance: CGFloat
    }

    var center: CGPoint
    var radius: CGFloat
    var cuts: [Cut]
}

/// Packs circles into a compact, slightly overlapping cluster and works out
/// each one's flat contact edges (the radical line between two overlapping
/// circles), so touching bubbles adapt their shape to each other.
enum FoamLayout {
    /// The white space left between two bubbles.
    static let gap: CGFloat = 6
    /// How far touching bubbles sink into each other, as a share of their
    /// combined radii. This is what produces the flat edges.
    private static let overlap: CGFloat = 0.1

    /// A single bubble is 300 across; the radius then shrinks with each one
    /// added, down to a floor, so several still fit.
    static func baseRadius(count: Int) -> CGFloat {
        max(56, 150 * max(0.63, 1 - 0.12 * CGFloat(max(count - 1, 0))))
    }

    /// A stable pseudo-random number in 0..<1 for a bubble, from its id, so
    /// its look doesn't change between launches. (`hashValue` is reseeded on
    /// every launch, so this hashes the id's text instead.)
    static func jitter(_ id: String, salt: UInt32 = 0) -> CGFloat {
        var hash: UInt32 = 2166136261 ^ salt
        for byte in id.utf8 { hash = (hash ^ UInt32(byte)) &* 16777619 }
        return CGFloat(hash % 1000) / 1000
    }

    /// A bubble's size follows the number of pods inside it: its *area* is
    /// proportional to the count, relative to the average, so a folder with
    /// four times the pods of another is twice as wide. Equal folders are
    /// equal; an empty one is small but never vanishes; none is wider than
    /// `maxRadius`. A lone bubble is exactly the base.
    static func radii(podCounts: [Int], base: CGFloat, maxRadius: CGFloat) -> [CGFloat] {
        guard podCounts.count > 1 else { return podCounts.map { _ in base } }
        let mean = max(CGFloat(podCounts.reduce(0, +)) / CGFloat(podCounts.count), 1)
        return podCounts.map { count in
            let factor = min(max(sqrt(max(CGFloat(count), 0.5) / mean), 0.55), 1.6)
            return min(base * factor, maxRadius)
        }
    }

    /// The packed positions: a compact cluster where bubbles sink a little
    /// into each other.
    static func pack(radii: [CGFloat], ids: [String], width: CGFloat, top: CGFloat) -> [CGPoint] {
        let n = radii.count
        guard n > 0 else { return [] }
        let average = radii.reduce(0, +) / CGFloat(n)

        // Start in an uneven zig-zag down the middle (each bubble nudged by
        // its own stable amount), then let it settle.
        var centers: [CGPoint] = radii.enumerated().map { index, r in
            let side: CGFloat = index % 2 == 0 ? -1 : 1
            let nudge = 0.4 + 1.2 * jitter(ids[index], salt: 7)
            return CGPoint(
                x: width / 2 + side * min(width * 0.3, r * 0.6 * nudge),
                y: top + r + CGFloat(index) * average * (1.2 + 0.5 * jitter(ids[index], salt: 3))
            )
        }

        for _ in 0..<300 {
            // Drift toward the middle column.
            for i in 0..<n { centers[i].x += (width / 2 - centers[i].x) * 0.015 }

            // Each bubble is drawn toward the two before it until it touches.
            for j in 1..<max(n, 1) {
                for k in max(0, j - 2)..<j {
                    let (d, ux, uy) = measure(centers[j], centers[k])
                    let target = (radii[j] + radii[k]) * (1 - overlap)
                    if d > target {
                        let pull = (d - target) * 0.05
                        centers[j].x -= ux * pull
                        centers[j].y -= uy * pull
                    }
                }
            }

            // Push apart any pair that sank in too far.
            for i in 0..<n {
                for j in (i + 1)..<max(n, i + 1) {
                    let (d, ux, uy) = measure(centers[j], centers[i])
                    let target = (radii[i] + radii[j]) * (1 - overlap)
                    if d < target {
                        let push = (target - d) / 2
                        centers[i].x -= ux * push
                        centers[i].y -= uy * push
                        centers[j].x += ux * push
                        centers[j].y += uy * push
                    }
                }
            }

            // Let the edges crop a bubble a little, like the reference.
            for i in 0..<n {
                centers[i].x = min(max(centers[i].x, -radii[i] * 0.15), width + radii[i] * 0.15)
            }
        }

        // Settle the whole cluster against the top.
        let topEdge = zip(centers, radii).map { $0.y - $1 }.min() ?? top
        let shift = top - topEdge
        for i in 0..<n { centers[i].y += shift }
        return centers
    }

    /// The cells for a set of packed `centers`. `looseness` 0 is as packed;
    /// 1 pushes the bubbles far enough apart that none touch (so they're
    /// plain circles again), in between is a partial spread.
    static func cells(centers packed: [CGPoint], radii: [CGFloat], width: CGFloat, top: CGFloat, looseness: CGFloat) -> [FoamCell] {
        let n = radii.count
        let l = min(max(looseness, 0), 1)
        var centers = packed.map { point in
            CGPoint(
                x: width / 2 + (point.x - width / 2) * (1 + 0.4 * l),
                y: top + (point.y - top) * (1 + 0.6 * l)
            )
        }
        for i in 0..<n {
            centers[i].x = min(max(centers[i].x, -radii[i] * 0.15), width + radii[i] * 0.15)
        }

        return (0..<n).map { i in
            var cuts: [FoamCell.Cut] = []
            for j in 0..<n where j != i {
                let (d, ux, uy) = measure(centers[j], centers[i])
                guard d > 0, d < radii[i] + radii[j] else { continue }
                let distance = (d * d + radii[i] * radii[i] - radii[j] * radii[j]) / (2 * d)
                if distance < radii[i] {
                    cuts.append(.init(direction: CGVector(dx: ux, dy: uy), distance: distance))
                }
            }
            return FoamCell(center: centers[i], radius: radii[i], cuts: cuts)
        }
    }

    /// Distance from `b` to `a`, and the unit vector from `b` toward `a`.
    private static func measure(_ a: CGPoint, _ b: CGPoint) -> (CGFloat, CGFloat, CGFloat) {
        let dx = a.x - b.x, dy = a.y - b.y
        let d = max(sqrt(dx * dx + dy * dy), 0.001)
        return (d, dx / d, dy / d)
    }
}

/// The outline of one cell: its circle, trimmed flat where neighbors press
/// in, with softly rounded corners where a flat edge meets the curve.
/// Drawn by `FoamCellView`.
struct FoamCellShape: Shape {
    var radius: CGFloat
    var cuts: [FoamCell.Cut]

    /// How round the corners are. The polygon is inset by this much, then
    /// stroked with a round join of twice the width.
    static let cornerRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let inner = max(radius - Self.cornerRadius, 1)
        var polygon: [CGPoint] = (0..<96).map { step in
            let angle = Double(step) / 96 * 2 * .pi
            return CGPoint(x: center.x + inner * CGFloat(cos(angle)), y: center.y + inner * CGFloat(sin(angle)))
        }
        for cut in cuts {
            polygon = Self.clip(
                polygon, center: center,
                direction: cut.direction,
                limit: cut.distance - FoamLayout.gap / 2 - Self.cornerRadius
            )
        }
        var path = Path()
        guard let first = polygon.first else { return path }
        path.move(to: first)
        for point in polygon.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    /// Sutherland–Hodgman: keep the part of `polygon` no further than
    /// `limit` along `direction` from `center`.
    private static func clip(_ polygon: [CGPoint], center: CGPoint, direction: CGVector, limit: CGFloat) -> [CGPoint] {
        func side(_ p: CGPoint) -> CGFloat {
            (p.x - center.x) * direction.dx + (p.y - center.y) * direction.dy - limit
        }
        var output: [CGPoint] = []
        for (index, current) in polygon.enumerated() {
            let previous = polygon[(index + polygon.count - 1) % polygon.count]
            let currentSide = side(current), previousSide = side(previous)
            if currentSide <= 0 {
                if previousSide > 0 { output.append(intersection(previous, current, previousSide, currentSide)) }
                output.append(current)
            } else if previousSide <= 0 {
                output.append(intersection(previous, current, previousSide, currentSide))
            }
        }
        return output
    }

    private static func intersection(_ a: CGPoint, _ b: CGPoint, _ sideA: CGFloat, _ sideB: CGFloat) -> CGPoint {
        let t = sideA / (sideA - sideB)
        return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

/// A cell filled in `color`, corners rounded.
struct FoamCellView: View {
    let cell: FoamCell
    var color: Color = .homePill

    var body: some View {
        let shape = FoamCellShape(radius: cell.radius, cuts: cell.cuts)
        ZStack {
            shape.fill(color)
            shape.stroke(color, style: StrokeStyle(lineWidth: FoamCellShape.cornerRadius * 2, lineJoin: .round))
        }
    }
}

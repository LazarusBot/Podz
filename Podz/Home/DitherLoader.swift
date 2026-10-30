import SwiftUI

/// The loading field on Lenny's search screen: an ordered-dither texture (an
/// 8 x 8 Bayer matrix thresholding a moving wave) in the ink color, drawn
/// as square "pixels". It drifts while Lenny works and fills in as the
/// steps are done (`progress` 0...1), so it says how far along the search
/// is without a number. Soft at the edges, no box. Still with Reduce Motion.
struct DitherLoader: View {
    /// 0...1, the share of steps done.
    var progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cell: CGFloat = 5

    /// The 8 x 8 Bayer threshold matrix, 0..<1.
    private static let bayer: [[Double]] = {
        var matrix: [[Int]] = [[0]]
        var size = 1
        while size < 8 {
            var next = Array(repeating: Array(repeating: 0, count: size * 2), count: size * 2)
            for y in 0..<size {
                for x in 0..<size {
                    let value = matrix[y][x] * 4
                    next[y][x] = value
                    next[y][x + size] = value + 2
                    next[y + size][x] = value + 3
                    next[y + size][x + size] = value + 1
                }
            }
            matrix = next
            size *= 2
        }
        return matrix.map { row in row.map { (Double($0) + 0.5) / 64 } }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { graphics, size in
                let columns = Int(size.width / cell)
                let rows = Int(size.height / cell)
                guard columns > 0, rows > 0 else { return }
                let level = 0.3 + 0.7 * progress

                var path = Path()
                for row in 0..<rows {
                    let v = Double(row) / Double(rows)
                    for column in 0..<columns {
                        let u = Double(column) / Double(columns)
                        // Two waves crossing, drifting at different speeds.
                        let waveA = sin((u * 5.0 - time * 0.55) * .pi + v * 3.0)
                        let waveB = sin((u * 2.3 + time * 0.3) * .pi - v * 4.5)
                        let wave = 0.5 + 0.25 * waveA + 0.25 * waveB
                        // Dense on the left, thinning to the right, the
                        // front moving right as the search advances.
                        let front = 1 - max(0, (u - progress * 0.85) / 0.5)
                        let density = wave * level * max(0, min(1, front))
                        if density > Self.bayer[row % 8][column % 8] {
                            path.addRect(CGRect(
                                x: CGFloat(column) * cell,
                                y: CGFloat(row) * cell,
                                width: cell - 1,
                                height: cell - 1
                            ))
                        }
                    }
                }
                graphics.fill(path, with: .color(Color.homeText))
            }
        }
        // Fades into the ground on every side.
        .mask {
            LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }
}

import SwiftUI

/// The loading texture behind Lenny's search screen: a light ordered dither
/// (an 8 x 8 Bayer matrix thresholding two slow waves) in the ink color,
/// drawn as square "pixels" over the whole screen. It only drifts, whatever
/// the steps are doing; it's there to say Lenny is working, not to track it.
/// Still with Reduce Motion.
struct DitherLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cell: CGFloat = 6

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
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { graphics, size in
                let columns = Int(size.width / cell)
                let rows = Int(size.height / cell)
                guard columns > 0, rows > 0 else { return }

                var path = Path()
                for row in 0..<rows {
                    let v = Double(row) / Double(rows)
                    for column in 0..<columns {
                        let u = Double(column) / Double(columns)
                        // Two waves crossing, drifting at different speeds.
                        let waveA = sin((u * 5.0 - time * 0.55) * .pi + v * 3.0)
                        let waveB = sin((u * 2.3 + time * 0.3) * .pi - v * 4.5)
                        let wave = 0.5 + 0.25 * waveA + 0.25 * waveB
                        // Sparse: well under half the pixels are ever lit.
                        let density = wave * 0.4
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
                graphics.fill(path, with: .color(Color.homeText.opacity(0.02)))
            }
        }
        .accessibilityHidden(true)
    }
}

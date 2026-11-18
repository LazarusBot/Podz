import SwiftUI

/// Lenny in the search: **no eyes, just his body**, a filled circle. He stays a
/// circle until something happens: each change in `burst` (you tap him, you type
/// a letter, the search starts or ends) makes him reshape, a blob that wobbles
/// and settles back into a circle in about a second. Color is the caller's (the
/// page's text color on the ground, or the ground on an inverted bar). Reduce
/// Motion: always a plain circle.
struct LennyBlob: View {
    var color: Color
    /// Changes on every reaction (a tap, a keystroke, a state change).
    var burst = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Every reaction starts from its own point in time, so no two wobbles match.
    @State private var seed = Double.random(in: 0..<1000)
    @State private var boost: CGFloat = 0
    /// The wobble is running (the clock only ticks while it does).
    @State private var isReacting = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isReacting)) { context in
            BlobShape(time: context.date.timeIntervalSinceReferenceDate + seed, amplitude: boost)
                .fill(color)
        }
        .task(id: burst) { await react() }
    }

    private func react() async {
        guard burst > 0, !reduceMotion else { return }
        isReacting = true
        seed = Double.random(in: 0..<1000)
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { boost = 0.22 }
        await Task.yield()
        withAnimation(.easeOut(duration: 1.1)) { boost = 0 }
        try? await Task.sleep(for: .seconds(1.2))
        if !Task.isCancelled { isReacting = false }
    }
}

/// A closed smooth curve through eight points whose distance from the center
/// breathes at its own pace: `amplitude` is how far (0 = a circle).
private struct BlobShape: Shape {
    var time: Double
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { amplitude }
        set { amplitude = newValue }
    }

    private static func noise(_ x: Double) -> Double {
        let v = sin(x) * 43758.5453
        return v - v.rounded(.down)
    }

    func path(in rect: CGRect) -> Path {
        let count = 8
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let amp = max(amplitude, 0)
        // The biggest the blob gets is still inside the frame.
        let base = min(rect.width, rect.height) / 2 / (1 + amp)
        let points: [CGPoint] = (0..<count).map { i in
            let angle = Double(i) / Double(count) * 2 * .pi
            let speed = 1.4 + 1.8 * Self.noise(Double(i) * 12.9898)
            let phase = 2 * .pi * Self.noise(Double(i) * 78.233)
            let radius = base * (1 + amp * CGFloat(sin(time * speed + phase)))
            return CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
        }
        // Catmull-Rom through the points, as cubic curves.
        var path = Path()
        path.move(to: points[0])
        for i in 0..<count {
            let p0 = points[(i + count - 1) % count]
            let p1 = points[i]
            let p2 = points[(i + 1) % count]
            let p3 = points[(i + 2) % count]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }
}

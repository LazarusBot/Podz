import SwiftUI

/// The loading texture behind Lenny's search screen: a huge planet rising
/// from the bottom edge, drawn as a stipple of tiny dots (after the Figma
/// "Planet" plugin). Only the land is drawn, and the dots thicken toward the
/// light, so the sphere reads from the density alone. It turns slowly, and
/// stays still with Reduce Motion.
struct PlanetLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How strong the dots are against the ground.
    private let opacity = 0.13
    /// Radians per second.
    private let spin = 0.12
    private let tilt = 0.15
    /// The planet's radius as a multiple of the screen width: far wider than
    /// the screen, so only its upper curve shows.
    private let radiusToWidth: CGFloat = 1.4
    private let dotRadius: CGFloat = 1.2
    /// Light from the upper left, toward the viewer.
    private let light = SIMD3<Double>(-0.55, -0.45, 0.7)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { graphics, size in
                let radius = size.width * radiusToWidth
                let center = CGPoint(x: size.width / 2, y: size.height)
                let angle = time * spin
                let (sinA, cosA) = (sin(angle), cos(angle))
                let (sinT, cosT) = (sin(tilt), cos(tilt))

                var path = Path()
                for point in Self.points {
                    // Turn about the vertical axis, then tip toward us.
                    let x = point.x * cosA + point.z * sinA
                    let z1 = -point.x * sinA + point.z * cosA
                    let y = point.y * cosT - z1 * sinT
                    let z = point.y * sinT + z1 * cosT
                    guard z > 0 else { continue }

                    let px = center.x + x * radius
                    guard px > -4, px < size.width + 4 else { continue }
                    let py = center.y + y * radius
                    guard py > -4 else { continue }

                    // Density by light: the lit side keeps most of its dots.
                    let lit = max(0, x * light.x + y * light.y + z * light.z)
                    guard point.chance < pow(lit, 0.8) * 1.05 else { continue }

                    path.addEllipse(in: CGRect(
                        x: px - dotRadius, y: py - dotRadius,
                        width: dotRadius * 2, height: dotRadius * 2
                    ))
                }
                graphics.fill(path, with: .color(Color.homeText.opacity(opacity)))
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - The planet's points

    private struct Point {
        let x: Double
        let y: Double
        let z: Double
        /// A fixed draw-or-not roll, 0..<1.
        let chance: Double
    }

    /// Land points on the upper hemisphere (the only part the horizon
    /// shows): Fibonacci-spaced, about 7pt apart at the planet's size.
    private static let points: [Point] = {
        let count = 39_000
        let golden = Double.pi * (3 - 5.0.squareRoot())
        var points: [Point] = []
        points.reserveCapacity(count / 2)
        for i in 0..<count {
            // y runs -1...0: the upper half.
            let y = -1 + (Double(i) + 0.5) / Double(count)
            let r = (1 - y * y).squareRoot()
            let theta = golden * Double(i)
            let x = cos(theta) * r
            let z = sin(theta) * r
            guard isLand(x, y, z) else { continue }
            points.append(Point(x: x, y: y, z: z, chance: (Double(i) * 0.6180339887).truncatingRemainder(dividingBy: 1)))
        }
        return points
    }()

    /// Continents: two octaves of value noise over the sphere's surface.
    private static func isLand(_ x: Double, _ y: Double, _ z: Double) -> Bool {
        let n = noise(x * 1.6 + 4, y * 1.6 + 2, z * 1.6) * 0.65
            + noise(x * 3.4, y * 3.4, z * 3.4) * 0.35
        return n > 0.5
    }

    private static func hash(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let h = sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453
        return h - h.rounded(.down)
    }

    private static func noise(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let (xi, yi, zi) = (x.rounded(.down), y.rounded(.down), z.rounded(.down))
        let (xf, yf, zf) = (x - xi, y - yi, z - zi)
        let (u, v, w) = (xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf), zf * zf * (3 - 2 * zf))
        func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
        let front = mix(
            mix(hash(xi, yi, zi), hash(xi + 1, yi, zi), u),
            mix(hash(xi, yi + 1, zi), hash(xi + 1, yi + 1, zi), u), v)
        let back = mix(
            mix(hash(xi, yi, zi + 1), hash(xi + 1, yi, zi + 1), u),
            mix(hash(xi, yi + 1, zi + 1), hash(xi + 1, yi + 1, zi + 1), u), v)
        return mix(front, back, w)
    }
}

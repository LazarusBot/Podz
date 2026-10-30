import SwiftUI

/// The loading texture behind Lenny's search screen: a huge planet rising
/// from the bottom edge, drawn as rows of tiny dots (after the Figma "Planet"
/// plugin): the dots sit on latitude rows, only the land is drawn, and each
/// dot's size follows the light, so the sphere reads from the dots alone. It
/// turns slowly, and stays still with Reduce Motion.
struct PlanetLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How strong the dots are against the ground.
    private let opacity = 0.07
    /// Radians per second.
    private let spin = 0.12
    private let tilt = 0.15
    /// The planet's radius as a multiple of the screen width: far wider than
    /// the screen, so only its upper curve shows.
    private let radiusToWidth: CGFloat = 1.4
    /// Dot radius in the light, and in the half-shadow where it fades out.
    private let litRadius: CGFloat = 1.9
    private let shadowRadius: CGFloat = 0.4
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

                    // Size by light: full dots in the light, shrinking into
                    // the shadow until they vanish at the terminator.
                    let lit = max(0, x * light.x + y * light.y + z * light.z)
                    guard lit > 0.03 else { continue }
                    let dot = shadowRadius + (litRadius - shadowRadius) * CGFloat(min(1, lit * 1.2))

                    path.addEllipse(in: CGRect(x: px - dot, y: py - dot, width: dot * 2, height: dot * 2))
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
    }

    /// Land points on the upper hemisphere (the only part the horizon
    /// shows), on latitude rows about 7pt apart at the planet's size, each
    /// row offset half a step from the one before.
    private static let points: [Point] = {
        let spacing = 7.0
        let referenceRadius = 393.0 * 1.4
        let rowStep = spacing / referenceRadius
        var points: [Point] = []
        var row = 0
        var latitude = 0.0
        while latitude < 1.48 {
            let y = -sin(latitude)
            let ring = cos(latitude)
            let count = max(1, Int((2 * .pi * ring * referenceRadius / spacing).rounded()))
            let offset = row.isMultiple(of: 2) ? 0.0 : 0.5
            for i in 0..<count {
                let theta = (Double(i) + offset) / Double(count) * 2 * .pi
                let x = ring * sin(theta)
                let z = ring * cos(theta)
                if isLand(x, y, z) { points.append(Point(x: x, y: y, z: z)) }
            }
            latitude += rowStep
            row += 1
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

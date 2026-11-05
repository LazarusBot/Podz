import SwiftUI
import CoreLocation

/// The route as a trace, like the thumbnail of a recorded run: one smooth
/// line through the huts in order (closed when it is a loop), a numbered dot
/// at each hut, drawn from the first to the last when the page opens. No map,
/// no chrome: only the shape of the trip.
struct LennyRoutePath: View {
    let points: [CLLocationCoordinate2D]
    var isLoop = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    private let dot: CGFloat = 20
    /// Room around the trace so the dots aren't cut.
    private let inset: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            let spots = project(points, in: proxy.size)
            ZStack {
                RouteCurve(points: spots, isClosed: isLoop)
                    .trim(from: 0, to: drawn)
                    .stroke(Color.homeText, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(Array(spots.enumerated()), id: \.offset) { index, spot in
                    Text(verbatim: "\(index + 1)")
                        .font(AppFont.semiBoldLabel(10))
                        .foregroundColor(.homeBackground)
                        .frame(width: dot, height: dot)
                        .background(Color.homeText, in: Circle())
                        // A ring in the ground colour keeps the dot clear of the line.
                        .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 2).padding(-2))
                        .position(spot)
                        .opacity(drawn >= CGFloat(index) / CGFloat(max(spots.count - 1, 1)) - 0.001 ? 1 : 0)
                        .animation(.easeOut(duration: 0.25), value: drawn)
                }
            }
        }
        .frame(height: 132)
        .onAppear {
            if reduceMotion {
                drawn = 1
            } else {
                withAnimation(.easeInOut(duration: 1.3).delay(0.2)) { drawn = 1 }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(tr("The route, \(points.count) huts"))
    }

    /// The huts as points in the frame, true to their shape (north up).
    private func project(_ coordinates: [CLLocationCoordinate2D], in size: CGSize) -> [CGPoint] {
        guard let first = coordinates.first else { return [] }
        var minLat = first.latitude, maxLat = first.latitude, minLng = first.longitude, maxLng = first.longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let stretch = cos((minLat + maxLat) / 2 * .pi / 180)
        let width = max((maxLng - minLng) * stretch, 0.0001)
        let height = max(maxLat - minLat, 0.0001)
        let room = CGSize(width: size.width - inset * 2, height: size.height - inset * 2)
        let scale = min(room.width / width, room.height / height)
        let offset = CGPoint(x: (size.width - width * scale) / 2, y: (size.height - height * scale) / 2)
        return coordinates.map { c in
            CGPoint(x: offset.x + (c.longitude - minLng) * stretch * scale, y: offset.y + (maxLat - c.latitude) * scale)
        }
    }
}

/// A smooth line through the points (Catmull-Rom, as Bézier segments).
private struct RouteCurve: Shape {
    let points: [CGPoint]
    let isClosed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        let count = points.count
        func point(_ index: Int) -> CGPoint {
            if isClosed { return points[((index % count) + count) % count] }
            return points[min(max(index, 0), count - 1)]
        }
        path.move(to: points[0])
        let segments = isClosed ? count : count - 1
        for index in 0..<segments {
            let p0 = point(index - 1), p1 = point(index), p2 = point(index + 1), p3 = point(index + 2)
            path.addCurve(
                to: p2,
                control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            )
        }
        return path
    }
}

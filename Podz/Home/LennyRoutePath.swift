import SwiftUI
import CoreLocation

/// The route as a trace, like the thumbnail of a recorded run: the real
/// hiking trail between each pair of huts (`HikingRouter`), a numbered dot at
/// each hut, drawn from the first to the last when the trails are found. No
/// map, no chrome: only the shape of the trip. While the trails load, and for
/// a leg with none, a faint dashed line joins the two huts.
struct LennyRoutePath: View {
    let huts: [CLLocationCoordinate2D]
    /// The trail of each leg, in order (one more for a loop's way back);
    /// `nil` where none was found.
    let legs: [[CLLocationCoordinate2D]?]
    /// Every trail has been looked for.
    let isReady: Bool
    var isLoop = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    private let dot: CGFloat = 20
    /// Room around the trace so the dots aren't cut.
    private let inset: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            let project = projection(in: proxy.size)
            let spots = huts.map(project)
            ZStack {
                // Where there is no trail (yet): a dashed line between the huts.
                Path { path in
                    for (index, leg) in legs.enumerated() where leg == nil {
                        guard let (from, to) = ends(of: index, spots: spots) else { continue }
                        path.move(to: from)
                        path.addLine(to: to)
                    }
                }
                .stroke(Color.homeText.opacity(isReady ? 0.45 : 0.25), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 5]))

                // The trails, one line from the first hut to the last.
                Path { path in
                    for leg in legs {
                        guard let leg, let first = leg.first else { continue }
                        path.move(to: project(first))
                        for coordinate in leg.dropFirst() { path.addLine(to: project(coordinate)) }
                    }
                }
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
                }
            }
        }
        .frame(height: 132)
        .onChange(of: isReady, initial: true) { _, ready in
            guard ready else { return }
            if reduceMotion {
                drawn = 1
            } else {
                withAnimation(.easeInOut(duration: 1.4)) { drawn = 1 }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(tr("The route, \(huts.count) huts"))
    }

    /// The two huts a leg joins (the last to the first for a loop's way back).
    private func ends(of leg: Int, spots: [CGPoint]) -> (CGPoint, CGPoint)? {
        guard spots.count >= 2 else { return nil }
        if leg < spots.count - 1 { return (spots[leg], spots[leg + 1]) }
        return isLoop ? (spots[spots.count - 1], spots[0]) : nil
    }

    /// Coordinates to points in the frame, true to their shape (north up),
    /// fitting the huts and every trail.
    private func projection(in size: CGSize) -> (CLLocationCoordinate2D) -> CGPoint {
        let all = huts + legs.flatMap { $0 ?? [] }
        guard let first = all.first else { return { _ in .zero } }
        var minLat = first.latitude, maxLat = first.latitude, minLng = first.longitude, maxLng = first.longitude
        for c in all {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let stretch = cos((minLat + maxLat) / 2 * .pi / 180)
        let width = max((maxLng - minLng) * stretch, 0.0001)
        let height = max(maxLat - minLat, 0.0001)
        let scale = min((size.width - inset * 2) / width, (size.height - inset * 2) / height)
        let offset = CGPoint(x: (size.width - width * scale) / 2, y: (size.height - height * scale) / 2)
        return { c in
            CGPoint(x: offset.x + (c.longitude - minLng) * stretch * scale, y: offset.y + (maxLat - c.latitude) * scale)
        }
    }
}

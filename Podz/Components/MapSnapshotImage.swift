import SwiftUI
import MapKit

/// A pod with no photo still gets a picture: the satellite view of where it is,
/// from Apple Maps, with a small marker on the spot. Snapshots are made once
/// per place and kept (a few at a time, so a screen of cards doesn't flood
/// Maps).
struct MapSnapshotImage: View {
    let coordinate: CLLocationCoordinate2D

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Rectangle().fill(Color.gray.opacity(0.25))
            }

            // The hut itself.
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 2)
                .opacity(image == nil ? 0 : 1)
        }
        .animation(.easeOut(duration: 0.3), value: image == nil)
        .task(id: "\(coordinate.latitude),\(coordinate.longitude)") {
            image = await MapSnapshotCache.shared.image(for: coordinate)
        }
        .accessibilityHidden(true)
    }
}

/// Makes and remembers the snapshots.
actor MapSnapshotCache {
    static let shared = MapSnapshotCache()

    private var cache: [String: UIImage] = [:]
    private var order: [String] = []
    private var inFlight = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private let limit = 3

    func image(for coordinate: CLLocationCoordinate2D) async -> UIImage? {
        let key = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        if let hit = cache[key] { return hit }

        await acquire()
        defer { release() }
        if let hit = cache[key] { return hit }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2600, longitudinalMeters: 2200)
        options.mapType = .satellite
        options.size = CGSize(width: 330, height: 390)
        options.scale = 2
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll

        for attempt in 0..<2 {
            do {
                let snapshot = try await MKMapSnapshotter(options: options).start()
                remember(snapshot.image, for: key)
                return snapshot.image
            } catch {
                if attempt == 0 { try? await Task.sleep(nanoseconds: 600_000_000) }
            }
        }
        return nil
    }

    private func remember(_ image: UIImage, for key: String) {
        cache[key] = image
        order.append(key)
        // About 60 pictures at a time.
        if order.count > 60 {
            cache[order.removeFirst()] = nil
        }
    }

    private func acquire() async {
        if inFlight < limit {
            inFlight += 1
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        if waiting.isEmpty {
            inFlight -= 1
        } else {
            waiting.removeFirst().resume()
        }
    }
}

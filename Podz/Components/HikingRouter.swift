import Foundation
import CoreLocation
import Combine

/// The trail between two huts: where it goes (simplified), how far, and how
/// much up and down.
struct HikingTrack: Codable, Equatable {
    /// Latitude / longitude pairs, simplified to a few dozen metres.
    let points: [[Double]]
    let km: Double
    let ascent: Int
    let descent: Int

    var coordinates: [CLLocationCoordinate2D] {
        points.compactMap { $0.count == 2 ? CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) : nil }
    }
}

/// Finds the hiking trail between two huts with BRouter (OpenStreetMap's
/// paths, the "hiking-mountain" profile: it follows marked trails, not
/// roads). Only the two huts' positions are sent, nothing about the user.
/// Every trail found is kept on the phone, so a route is asked for once.
actor HikingRouter {
    static let shared = HikingRouter()

    private var memory: [String: HikingTrack] = [:]
    private var missing: Set<String> = []

    /// Further apart than this isn't a day on the trail: no request is made.
    static let maximumKm = 60.0

    func track(from: Pod, to: Pod) async -> HikingTrack? {
        guard let lat1 = from.latitude, let lng1 = from.longitude,
              let lat2 = to.latitude, let lng2 = to.longitude,
              LennyAreaRoute.distance(lat1, lng1, lat2, lng2) <= Self.maximumKm
        else { return nil }
        let key = "\(from.id.uuidString)-\(to.id.uuidString)"
        if let known = memory[key] ?? Self.readFromDisk(key) {
            memory[key] = known
            return known
        }
        if missing.contains(key) { return nil }

        guard let found = await Self.fetch(lat1, lng1, lat2, lng2) else {
            // A network failure may pass; "no trail" is kept for this session only.
            missing.insert(key)
            return nil
        }
        memory[key] = found
        Self.writeToDisk(found, key)
        return found
    }

    // MARK: - BRouter

    private static func fetch(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) async -> HikingTrack? {
        var components = URLComponents(string: "https://brouter.de/brouter")
        components?.queryItems = [
            URLQueryItem(name: "lonlats", value: "\(lng1),\(lat1)|\(lng2),\(lat2)"),
            URLQueryItem(name: "profile", value: "hiking-mountain"),
            URLQueryItem(name: "alternativeidx", value: "0"),
            URLQueryItem(name: "format", value: "geojson")
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Podz (iOS)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let feature = (json["features"] as? [[String: Any]])?.first,
              let geometry = feature["geometry"] as? [String: Any],
              let raw = geometry["coordinates"] as? [[Double]], raw.count >= 2
        else { return nil }
        return summarize(raw)
    }

    /// Distance and climbs from the raw track (lng, lat, altitude), then the
    /// line simplified for drawing.
    static func summarize(_ raw: [[Double]]) -> HikingTrack {
        var meters = 0.0
        var ascent = 0.0, descent = 0.0
        // A climb counts once the altitude has moved 5 m, so GPS-like noise doesn't add up.
        var reference = raw.first.flatMap { $0.count > 2 ? $0[2] : nil }
        for (index, point) in raw.enumerated() {
            if index > 0 {
                let before = raw[index - 1]
                meters += CLLocation(latitude: before[1], longitude: before[0])
                    .distance(from: CLLocation(latitude: point[1], longitude: point[0]))
            }
            guard point.count > 2, let base = reference else { continue }
            let step = point[2] - base
            if step >= 5 { ascent += step; reference = point[2] }
            else if step <= -5 { descent -= step; reference = point[2] }
        }
        let line = raw.map { [$0[1], $0[0]] }
        return HikingTrack(
            points: simplify(line, tolerance: 0.0003),
            km: meters / 1000,
            ascent: Int(ascent.rounded()),
            descent: Int(descent.rounded())
        )
    }

    /// Douglas-Peucker, in degrees (0.0003° is about 30 m).
    static func simplify(_ points: [[Double]], tolerance: Double) -> [[Double]] {
        guard points.count > 2 else { return points }
        var keep = Array(repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack = [(0, points.count - 1)]
        while let (start, end) = stack.popLast() {
            guard end - start > 1 else { continue }
            var farthest = 0.0
            var index = start
            for i in (start + 1)..<end {
                let d = offset(points[i], from: points[start], to: points[end])
                if d > farthest { farthest = d; index = i }
            }
            if farthest > tolerance {
                keep[index] = true
                stack.append((start, index))
                stack.append((index, end))
            }
        }
        return points.indices.filter { keep[$0] }.map { points[$0] }
    }

    private static func offset(_ p: [Double], from a: [Double], to b: [Double]) -> Double {
        let dx = b[0] - a[0], dy = b[1] - a[1]
        let length = dx * dx + dy * dy
        guard length > 0 else { return hypot(p[0] - a[0], p[1] - a[1]) }
        let t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / length))
        return hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy))
    }

    // MARK: - On the phone

    private static var folder: URL? {
        try? FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("HikingTracks", isDirectory: true)
    }

    private static func readFromDisk(_ key: String) -> HikingTrack? {
        guard let file = folder?.appendingPathComponent("\(key).json"),
              let data = try? Data(contentsOf: file)
        else { return nil }
        return try? JSONDecoder().decode(HikingTrack.self, from: data)
    }

    private static func writeToDisk(_ track: HikingTrack, _ key: String) {
        guard let folder, let data = try? JSONEncoder().encode(track) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent("\(key).json"), options: .atomic)
    }
}

/// The trails of a route, found while its summary is on screen.
@MainActor
final class LennyRouteTracks: ObservableObject {
    /// By leg: the hut it leaves from, and the one it reaches.
    @Published private(set) var tracks: [String: HikingTrack] = [:]
    @Published private(set) var isDone = false
    private var loaded = ""

    nonisolated static func key(_ from: Pod, _ to: Pod) -> String { "\(from.id.uuidString)-\(to.id.uuidString)" }

    /// Looks for every leg (three at a time, to go easy on the server); runs once for a given route.
    func load(legs: [(Pod, Pod)]) async {
        let id = legs.map { Self.key($0.0, $0.1) }.joined(separator: ",")
        guard id != loaded else { return }
        loaded = id
        isDone = false
        var index = 0
        while index < legs.count {
            let batch = Array(legs[index..<min(index + 3, legs.count)])
            index += 3
            await withTaskGroup(of: (String, HikingTrack?).self) { group in
                for (from, to) in batch {
                    group.addTask { (Self.key(from, to), await HikingRouter.shared.track(from: from, to: to)) }
                }
                for await (key, track) in group {
                    if let track { tracks[key] = track }
                }
            }
            if Task.isCancelled { return }
        }
        isDone = true
    }
}

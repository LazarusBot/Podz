import Foundation

/// A day on the route between two huts: how far, how much higher or lower,
/// and about how long. Straight-line distance stretched for the bends of a
/// trail, and the time a walker needs (4 km/h, plus an hour for every 600 m
/// up). Only an estimate, and said so ("~").
struct LennyStage {
    let km: Double
    /// Net climb between the two huts, when both altitudes are known (negative going down).
    let climb: Int?
    let hours: Double

    /// A trail winds: 30% on top of the crow's flight.
    private static let windingFactor = 1.3

    static func between(_ from: Pod, _ to: Pod) -> LennyStage? {
        guard let lat1 = from.latitude, let lng1 = from.longitude,
              let lat2 = to.latitude, let lng2 = to.longitude
        else { return nil }
        let km = LennyAreaRoute.distance(lat1, lng1, lat2, lng2) * windingFactor
        var climb: Int?
        if let a = from.altitudeM, let b = to.altitudeM { climb = b - a }
        let up = Double(max(climb ?? 0, 0))
        return LennyStage(km: km, climb: climb, hours: km / 4 + up / 600)
    }

    /// "27 km · +450 m · ~7 h".
    var text: String {
        var parts = ["\(Int(km.rounded())) km"]
        if let climb, abs(climb) >= 10 { parts.append(climb > 0 ? "+\(climb) m" : "−\(-climb) m") }
        parts.append("~\(Self.duration(hours))")
        return parts.joined(separator: " · ")
    }

    /// "~45 min", "~7 h", "~6 h 30" (to the nearest 30 minutes from an hour on).
    static func duration(_ hours: Double) -> String {
        guard hours >= 1 else { return "\(max(5, Int((hours * 60 / 5).rounded()) * 5)) min" }
        let halves = Int((hours * 2).rounded())
        return halves % 2 == 0 ? "\(halves / 2) h" : "\(halves / 2) h 30"
    }
}

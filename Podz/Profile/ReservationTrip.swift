import Foundation

/// Stays booked in one go, one after the other, are one trip: that is what
/// Lenny's plan books (each stop starts the day the last one ends, all
/// created within moments, for the same guests). A stay booked alone is a
/// trip of one.
struct ReservationTrip: Identifiable {
    let stays: [Reservation]

    var id: UUID { stays[0].id }
    var guests: Int { stays[0].guests }
    var checkIn: String { stays[0].checkIn }
    var checkOut: String { stays[stays.count - 1].checkOut }
    /// More than one stay in a row can only be a plan.
    var isPlannedWithLenny: Bool { stays.count > 1 }

    var nights: Int {
        guard let start = Reservation.date(from: checkIn), let end = Reservation.date(from: checkOut) else { return 0 }
        return max(Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    /// Chains `reservations` (any order) into trips.
    static func group(_ reservations: [Reservation]) -> [ReservationTrip] {
        var groups: [[Reservation]] = []
        for reservation in reservations.sorted(by: { ($0.checkIn, $0.createdAt) < ($1.checkIn, $1.createdAt) }) {
            if let last = groups.last?.last,
               !last.isExternal, !reservation.isExternal,
               last.checkOut == reservation.checkIn,
               last.guests == reservation.guests,
               abs(reservation.createdAt.timeIntervalSince(last.createdAt)) < 120 {
                groups[groups.count - 1].append(reservation)
            } else {
                groups.append([reservation])
            }
        }
        return groups.map(ReservationTrip.init)
    }
}

extension Reservation {
    /// The nights of this stay.
    var nights: Int {
        guard let start = Self.date(from: checkIn), let end = Self.date(from: checkOut) else { return 0 }
        return max(Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    /// "Sat 31 Oct → Mon 2 Nov": the dates are plain days (UTC), so they're
    /// shown in UTC too, whatever the phone's time zone.
    static func rangeText(_ checkIn: String, _ checkOut: String) -> String {
        guard let start = date(from: checkIn), let end = date(from: checkOut) else { return "\(checkIn) → \(checkOut)" }
        let format = Date.FormatStyle(timeZone: TimeZone(identifier: "UTC") ?? .gmt).weekday(.abbreviated).day().month(.abbreviated)
        return "\(start.formatted(format)) → \(end.formatted(format))"
    }
}

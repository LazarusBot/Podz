//
//  Reservation.swift
//  Podz
//
//  Created by Max Prx on 01/09/2026.
//

import Foundation

/// Mirrors a row in the `reservations` table (see SQL/reservations.sql) —
/// a stay booked against a pod's overall `beds_total`, no payment
/// collected here (settled at the shelter, same as many real mountain
/// refuges already work).
///
/// `checkIn`/`checkOut` stay `String` ("yyyy-MM-dd"), not `Date` — a
/// Postgres `date` column serializes over PostgREST as a bare date string
/// with no time component, and supabase-swift's default date decoder only
/// accepts full ISO8601 timestamps (see `Helpers/DateFormatter.swift`),
/// so decoding straight into `Date` would throw on every row. Use
/// `Reservation.dateFormatter` to convert at the UI boundary instead.
struct Reservation: Codable, Identifiable, Equatable {
    let id: UUID
    let podId: UUID
    let userId: UUID
    var checkIn: String
    var checkOut: String
    var guests: Int
    var status: String
    let createdAt: Date
    /// "external" for a stay the traveler booked through the hut and added to
    /// their list; nil or "podz" for a booking made in the app.
    var source: String?

    enum CodingKeys: String, CodingKey {
        case id
        case podId = "pod_id"
        case userId = "user_id"
        case checkIn = "check_in"
        case checkOut = "check_out"
        case guests
        case status
        case createdAt = "created_at"
        case source
    }

    var isExternal: Bool { source == "external" }

    var isUpcoming: Bool {
        status == "confirmed" && (Self.date(from: checkOut) ?? .distantPast) >= Calendar.current.startOfDay(for: Date())
    }

    /// Shared "yyyy-MM-dd" formatter — the exact shape a Postgres `date`
    /// column round-trips as over PostgREST, in both directions.
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    static func date(from string: String) -> Date? {
        dateFormatter.date(from: string)
    }

    static func string(from date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

struct ReservationInsert: Codable {
    let podId: UUID
    let userId: UUID
    let checkIn: String
    let checkOut: String
    let guests: Int
    /// Only sent for an external stay, so a plain booking works before
    /// SQL/external_reservations.sql has been run.
    var source: String?

    enum CodingKeys: String, CodingKey {
        case podId = "pod_id"
        case userId = "user_id"
        case checkIn = "check_in"
        case checkOut = "check_out"
        case guests
        case source
    }
}

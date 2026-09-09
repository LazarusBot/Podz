//
//  TripPass.swift
//  Podz
//
//  Created by Max Prx on 07/09/2026.
//

import Foundation

/// A denormalized, disk-persisted snapshot of one upcoming reservation
/// plus just enough of its pod to render an offline pass — see
/// `TripPassStore`. Deliberately not `Reservation` + `Pod` themselves:
/// those live only in memory (`ReservationsStore`/`PodsStore`, refetched
/// from Supabase every session) and would both be empty on a cold launch
/// with no signal, which is exactly the situation this exists for.
struct TripPass: Codable, Identifiable, Equatable {
    let reservationId: UUID
    let podId: UUID
    var podName: String
    var address: String?
    var region: String?
    var country: String
    var latitude: Double?
    var longitude: Double?
    var altitudeM: Int?
    var photoURL: String?
    var checkIn: String
    var checkOut: String
    var guests: Int

    var id: UUID { reservationId }

    /// Short, human-readable stand-in for a real booking reference — this
    /// app has no separate confirmation-number column, so the
    /// reservation's own id (already unique, already stable) doubles as
    /// one instead of adding a column nothing else needs.
    var confirmationCode: String {
        reservationId.uuidString.prefix(8).uppercased()
    }

    /// What the pass's barcode actually encodes — a refuge with no signal
    /// also has no way to hit an API to validate a scan, so this is
    /// deliberately just a plain, self-contained string (not a URL to
    /// some endpoint), meant to be read against the same code printed
    /// below it, not scanned by a live system.
    var barcodePayload: String {
        "PODZ-\(confirmationCode)"
    }
}

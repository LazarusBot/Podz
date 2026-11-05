//
//  ReservationsStore.swift
//  Podz
//
//  Created by Max Prx on 01/09/2026.
//

import Foundation
import Combine
import SwiftUI
import Supabase

/// Your own reservations — see SQL/reservations.sql for the table and its
/// capacity-enforcing trigger. Same shape as MessagesStore: a singleton
/// backing store, optimistic local updates on write, `lastError` for the
/// UI to surface failures (including the trigger's "not enough beds"
/// error, shown the same way any other failure is — no special-casing).
@MainActor
final class ReservationsStore: ObservableObject {
    static let shared = ReservationsStore()

    @Published private(set) var reservations: [Reservation] = []
    /// The guests behind `hostedReservations` — same
    /// batch-fetch-only-what's-missing pattern as `PostsStore.profilesById`.
    @Published private(set) var profilesById: [UUID: Profile] = [:]
    @Published var lastError: String?
    /// The stay just added, so the Reservations page can show that it's new.
    @Published var lastAddedId: UUID?

    private init() {}

    /// Forgets the signed-out account's stays, so the next one on this phone
    /// never sees them.
    func clear() {
        reservations = []
        lastAddedId = nil
        lastError = nil
    }

    /// Returns whether it succeeded — `TripPassStore` uses this to tell a
    /// real fetch failure (leaves `reservations` untouched, same as
    /// always) apart from a genuinely empty result, so it doesn't wipe
    /// its own disk cache with nothing just because this ran offline.
    @discardableResult
    func fetchMine() async -> Bool {
        guard let userId = AuthManager.shared.session?.user.id else { return false }
        do {
            reservations = try await supabase
                .from("reservations")
                .select()
                .eq("user_id", value: userId)
                .order("check_in")
                .execute()
                .value
            OfflineStorage.save(reservations, as: "reservations-\(userId.uuidString)", personal: true)
            return true
        } catch {
            lastError = error.localizedDescription
            // No signal: your reservations from the last time, so the page isn't
            // empty up there.
            if reservations.isEmpty, let kept = OfflineStorage.load([Reservation].self, named: "reservations-\(userId.uuidString)") {
                reservations = kept
            }
            return false
        }
    }

    /// Returns whether it succeeded — the caller (ReservationSheet) uses
    /// this to decide whether to show its confirmation state, same
    /// boolean-return shape as `AuthManager.resetPassword`.
    func create(podId: UUID, checkIn: Date, checkOut: Date, guests: Int, source: String? = nil) async -> Bool {
        guard let userId = AuthManager.shared.session?.user.id else { return false }
        lastError = nil

        do {
            let inserted: Reservation = try await supabase
                .from("reservations")
                .insert(
                    ReservationInsert(
                        podId: podId,
                        userId: userId,
                        checkIn: Reservation.string(from: checkIn),
                        checkOut: Reservation.string(from: checkOut),
                        guests: guests,
                        source: source
                    )
                )
                .select()
                .single()
                .execute()
                .value
            reservations.append(inserted)
            lastAddedId = inserted.id
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Optimistic, matching `MessagesStore.markRead`'s pattern — flips
    /// local state first, reverts if the server call fails.
    func cancel(_ reservation: Reservation) async {
        guard let index = reservations.firstIndex(where: { $0.id == reservation.id }) else { return }
        let previousStatus = reservations[index].status
        reservations[index].status = "cancelled"

        do {
            try await supabase
                .from("reservations")
                .update(["status": "cancelled"])
                .eq("id", value: reservation.id)
                .execute()
        } catch {
            reservations[index].status = previousStatus
            lastError = error.localizedDescription
        }
    }
}

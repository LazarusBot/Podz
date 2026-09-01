//
//  ReservationsStore.swift
//  Podz
//
//  Created by Max Prx on 01/09/2026.
//

import Foundation
import Combine
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
    @Published var lastError: String?

    private init() {}

    func fetchMine() async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        do {
            reservations = try await supabase
                .from("reservations")
                .select()
                .eq("user_id", value: userId)
                .order("check_in")
                .execute()
                .value
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Returns whether it succeeded — the caller (ReservationSheet) uses
    /// this to decide whether to show its confirmation state, same
    /// boolean-return shape as `AuthManager.resetPassword`.
    func create(podId: UUID, checkIn: Date, checkOut: Date, guests: Int) async -> Bool {
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
                        guests: guests
                    )
                )
                .select()
                .single()
                .execute()
                .value
            reservations.append(inserted)
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

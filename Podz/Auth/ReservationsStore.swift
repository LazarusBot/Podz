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
    /// Reservations made *against* pods this host owns — not `reservations`
    /// above, which is the guest side (your own bookings elsewhere). A
    /// completely separate array rather than folding into the same one,
    /// since a host viewing their own pods' bookings and a guest viewing
    /// their own trips are different questions with different RLS access
    /// paths (see SQL/host_guests.sql) even for the same signed-in user.
    @Published private(set) var hostedReservations: [Reservation] = []
    /// The guests behind `hostedReservations` — same
    /// batch-fetch-only-what's-missing pattern as `PostsStore.profilesById`.
    @Published private(set) var profilesById: [UUID: Profile] = [:]
    @Published var lastError: String?
    /// Transient "+1" badge on the Pods tab — a self-clearing
    /// confirmation, not a persistent unread-style count, since there's nothing ongoing to
    /// track here (just "a reservation was made, go look").
    @Published private(set) var showRecentReservationBadge = false
    private var recentReservationBadgeTask: Task<Void, Never>?

    private init() {}

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
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Every reservation across every pod this host owns, most recent
    /// `checkIn` first is left to the caller (sorted here by `check_in`
    /// ascending, same as `fetchMine`) — `HostGuestsView` splits it into
    /// upcoming/past itself, same as `MyReservationsView` already does
    /// for the guest side. Re-fetches the host's own pod list first
    /// rather than trusting `PodsStore.shared.pods` is already populated
    /// — this can be the very first thing that runs if Guests is opened
    /// before Pods ever was.
    func fetchForHostedPods() async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        await PodsStore.shared.fetchPods()
        let podIds = PodsStore.shared.pods.filter { $0.hostId == userId }.map(\.id)
        guard !podIds.isEmpty else {
            hostedReservations = []
            return
        }
        do {
            hostedReservations = try await supabase
                .from("reservations")
                .select()
                .in("pod_id", values: podIds.map { $0.uuidString })
                .order("check_in")
                .execute()
                .value
            await fetchProfilesIfNeeded(for: Set(hostedReservations.map { $0.userId }))
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fetchProfilesIfNeeded(for userIds: Set<UUID>) async {
        let missing = userIds.filter { profilesById[$0] == nil }
        guard !missing.isEmpty else { return }
        do {
            let fetched: [Profile] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: Array(missing).map { $0.uuidString })
                .execute()
                .value
            for profile in fetched {
                profilesById[profile.id] = profile
            }
        } catch {
            // Non-fatal — the row just shows a fallback name.
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
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Kicks off the transient "+1" badge on the Pods tab.
    /// `ReservationSheet` never actually covers the tab bar (it grows in
    /// place inside `PodDetailView`, which doesn't hide it), so the call
    /// site (`ReservationSheet.submit()`) fires this once its own
    /// "Reservation confirmed" state has already shown and is collapsing
    /// away, not the moment `create()` resolves — reads as one
    /// confirmation handing off to the next rather than both firing at
    /// once.
    func flashRecentReservationBadge() {
        recentReservationBadgeTask?.cancel()
        // Low damping fraction on purpose — lets the spring overshoot
        // past its resting scale before settling, which reads as an
        // actual "pop" rather than a plain fade/grow-in.
        withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) {
            showRecentReservationBadge = true
        }
        recentReservationBadgeTask = Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: AppMotion.standard)) {
                showRecentReservationBadge = false
            }
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

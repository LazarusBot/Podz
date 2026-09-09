//
//  TripPassStore.swift
//  Podz
//
//  Created by Max Prx on 07/09/2026.
//

import Foundation
import Combine

/// Keeps upcoming trips' pass data on disk, not just in memory — so
/// `PodsView`'s hero card and `TripPassView` still have something real to
/// show on a cold launch with no signal, which `ReservationsStore`/
/// `PodsStore` alone can't promise (both start empty and refetch from
/// Supabase every session).
///
/// `refresh` is the only writer, and it's the caller's job (see
/// `PodsView`'s own `.task`) to only call it once `fetchMine()`/
/// `fetchPods()` have both actually *succeeded* — passing in reservations
/// that are merely empty because a fetch just failed offline would wipe
/// a perfectly good disk cache with nothing, defeating the entire point.
@MainActor
final class TripPassStore: ObservableObject {
    static let shared = TripPassStore()

    @Published private(set) var passes: [TripPass] = []

    private let cacheURL: URL

    private init() {
        // Application Support, not Caches — the whole point of this store
        // is surviving being offline for a while, and Caches/ is fair
        // game for the system to purge under storage pressure at exactly
        // the wrong moment (mid-trip, no signal to refetch).
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        cacheURL = appSupport.appendingPathComponent("trip_passes.json")
        passes = Self.loadFromDisk(at: cacheURL)
    }

    private static func loadFromDisk(at url: URL) -> [TripPass] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([TripPass].self, from: data) else {
            return []
        }
        return decoded
    }

    /// Rebuilds `passes` from reservations/pods the caller already fetched
    /// successfully this session, and persists the result — so the disk
    /// copy is always the last successful fetch, never a partial or
    /// failed one. `photosByPodId` mirrors `PodsStore.primaryPhotoByPodId`
    /// rather than reading it directly, so this stays testable without a
    /// live store.
    func refresh(reservations: [Reservation], pods: [Pod], photosByPodId: [UUID: String]) {
        let podsById = Dictionary(uniqueKeysWithValues: pods.map { ($0.id, $0) })
        passes = reservations
            .filter { $0.isUpcoming }
            .compactMap { reservation -> TripPass? in
                guard let pod = podsById[reservation.podId] else { return nil }
                return TripPass(
                    reservationId: reservation.id,
                    podId: pod.id,
                    podName: pod.name,
                    address: pod.address,
                    region: pod.region,
                    country: pod.country,
                    latitude: pod.latitude,
                    longitude: pod.longitude,
                    altitudeM: pod.altitudeM,
                    photoURL: photosByPodId[pod.id],
                    checkIn: reservation.checkIn,
                    checkOut: reservation.checkOut,
                    guests: reservation.guests
                )
            }
            .sorted { $0.checkIn < $1.checkIn }

        guard let data = try? JSONEncoder().encode(passes) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

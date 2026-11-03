//
//  PodsStore.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

import Foundation
import Combine
import Supabase
import Storage
import CoreLocation
import UIKit

@MainActor
final class PodsStore: ObservableObject {
    static let shared = PodsStore()
    
    @Published private(set) var pods: [Pod] = []
    @Published private(set) var primaryPhotoByPodId: [UUID: String] = [:]
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    
    /// The last good fetch on disk, so Home has pods to show the moment the app
    /// opens while the real fetch runs.
    nonisolated private static let cacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = caches.appendingPathComponent("PodzCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
    nonisolated private static var podsFile: URL { cacheDirectory.appendingPathComponent("pods.json") }
    nonisolated private static var photosFile: URL { cacheDirectory.appendingPathComponent("primary-photos.json") }

    /// A fetch already running is shared, and a recent good one is reused.
    private var inFlight: Task<Bool, Never>?
    private var lastFetch: Date?
    private let freshFor: TimeInterval = 90

    private init() {
        Task { await loadDiskCache() }
    }

    private func loadDiskCache() async {
        let cached = await Task.detached(priority: .userInitiated) { () -> ([Pod], [UUID: String])? in
            guard let podsData = try? Data(contentsOf: Self.podsFile),
                  let pods = try? JSONDecoder().decode([Pod].self, from: podsData) else { return nil }
            let photos = (try? Data(contentsOf: Self.photosFile))
                .flatMap { try? JSONDecoder().decode([UUID: String].self, from: $0) } ?? [:]
            return (pods, photos)
        }.value
        // The real fetch may have won the race: never replace fresher data.
        guard let cached, pods.isEmpty else { return }
        pods = cached.0
        primaryPhotoByPodId = cached.1
    }

    private func saveDiskCache(pods: [Pod], photos: [UUID: String]) {
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(pods) { try? data.write(to: Self.podsFile) }
            if let data = try? JSONEncoder().encode(photos) { try? data.write(to: Self.photosFile) }
        }
    }

    /// Returns whether it succeeded — same reasoning as
    /// `ReservationsStore.fetchMine`'s own boolean return: `TripPassStore`
    /// needs to tell a real fetch failure apart from a genuinely empty
    /// result before it overwrites its own disk cache.
    ///
    /// Called from several places at launch (Home, the trip passes,
    /// reservations): they now share one fetch, and a good one from the last
    /// minute and a half is reused (`force` skips that).
    @discardableResult
    func fetchPods(force: Bool = false) async -> Bool {
        if let inFlight { return await inFlight.value }
        if !force, let lastFetch, Date().timeIntervalSince(lastFetch) < freshFor, !pods.isEmpty { return true }
        let task = Task { await self.loadFromServer() }
        inFlight = task
        let ok = await task.value
        inFlight = nil
        if ok { lastFetch = Date() }
        return ok
    }

    private func loadFromServer() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            // The photos are fetched alongside the pods, not after them.
            async let photos = fetchPrimaryPhotos()
            // PostgREST returns at most 1,000 rows a request: read them page by
            // page.
            var all: [Pod] = []
            let pageSize = 1000
            while true {
                let page: [Pod] = try await supabase
                    .from("pods")
                    .select()
                    .eq("is_active", value: true)
                    .order("name")
                    .order("id")
                    .range(from: all.count, to: all.count + pageSize - 1)
                    .execute()
                    .value
                all += page
                if page.count < pageSize { break }
            }
            let fetchedPhotos = await photos
            pods = all
            // A failed photo fetch keeps what's there (cards just show the
            // placeholder or the satellite view).
            if let fetchedPhotos { primaryPhotoByPodId = fetchedPhotos }
            saveDiskCache(pods: all, photos: primaryPhotoByPodId)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Loads just the first photo (position 0) of each *active* pod (the join
    /// leaves out the countries that are switched off) — enough for the Home
    /// cards. The full carousel is fetched separately on the detail screen.
    /// `nil` when it failed.
    private func fetchPrimaryPhotos() async -> [UUID: String]? {
        do {
            // Page by page: PostgREST returns at most 1,000 rows a request.
            var all: [PodPhotoRow] = []
            let pageSize = 1000
            while true {
                let page: [PodPhotoRow] = try await supabase
                    .from("pod_photos")
                    .select("pod_id, url, position, pods!inner(is_active)")
                    .eq("position", value: 0)
                    .eq("pods.is_active", value: true)
                    .order("pod_id")
                    .range(from: all.count, to: all.count + pageSize - 1)
                    .execute()
                    .value
                all += page
                if page.count < pageSize { break }
            }
            return all.reduce(into: [:]) { result, photo in
                result[photo.podId] = photo.url  // last one wins, never crashes on duplicates
            }
        } catch {
            return nil
        }
    }

    func pods(inCountry country: String) -> [Pod] {
        pods.filter { $0.country == country }
    }
    
    /// Same as above, with an optional pod_type filter. Pass nil or
    /// "All types" to skip filtering by type.
    func pods(inCountry country: String, type: String?) -> [Pod] {
        pods.filter { pod in
            pod.country == country && (type == nil || type == "All types" || pod.podType == type)
        }
    }
    
    /// `pod.bedsTotal` is the shelter's static total capacity — it never
    /// reflects who's actually booked. This calls the `beds_available_now`
    /// RPC (see SQL/beds_available.sql) instead, which subtracts every
    /// guest's *confirmed* reservations covering today server-side —
    /// client-side RLS only ever exposes your own reservations, so this is
    /// the only way to get a real cross-user count. `nil` on failure (RPC
    /// not deployed yet, network error, ...) — the caller falls back to
    /// the static total rather than showing a broken number.
    func bedsAvailableNow(forPodId podId: UUID) async -> Int? {
        do {
            return try await supabase
                .rpc("beds_available_now", params: ["p_pod_id": podId])
                .execute()
                .value
        } catch {
            return nil
        }
    }

    /// Full ordered photo set for a pod's detail screen — fetchPrimaryPhotos
    /// only grabs position 0, enough for the Home cards.
    func photos(forPodId podId: UUID) async -> [String] {
        await photoRows(forPodId: podId).map(\.url)
    }

    /// The same photos with their credit, for the ones taken from Wikimedia
    /// Commons.
    func photoRows(forPodId podId: UUID) async -> [PodPhotoRow] {
        let name = "photos-\(podId.uuidString)"
        do {
            let rows: [PodPhotoRow] = try await supabase
                .from("pod_photos")
                .select("pod_id, url, position, credit")
                .eq("pod_id", value: podId)
                .order("position")
                .execute()
                .value
            // Kept for when there's no signal.
            OfflineStorage.save(rows, as: name)
            return rows
        } catch {
            // No signal: the copy from the last time, if there is one.
            if let kept = OfflineStorage.load([PodPhotoRow].self, named: name), !kept.isEmpty { return kept }
            // Before the credit column exists, ask for the plain columns.
            if let plain: [PodPhotoRow] = try? await supabase
                .from("pod_photos")
                .select("pod_id, url, position")
                .eq("pod_id", value: podId)
                .order("position")
                .execute()
                .value {
                return plain
            }
            lastError = error.localizedDescription
            return []
        }
    }
    
    /// Simple client-side proximity search — fine at this data scale.
    /// Move to a PostGIS query server-side once the pods table grows large.
    func pods(near coordinates: [CLLocationCoordinate2D], radiusKm: Double) -> [Pod] {
        pods.filter { pod in
            guard let lat = pod.latitude, let lng = pod.longitude else { return false }
            let podLocation = CLLocation(latitude: lat, longitude: lng)
            return coordinates.contains { coordinate in
                let stopLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                return podLocation.distance(from: stopLocation) / 1000 <= radiusKm
            }
        }
    }
}

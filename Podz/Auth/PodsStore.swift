//
//  PodsStore.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

import Foundation
import Combine
import Supabase
import CoreLocation

@MainActor
final class PodsStore: ObservableObject {
    static let shared = PodsStore()
    
    @Published private(set) var pods: [Pod] = []
    @Published private(set) var primaryPhotoByPodId: [UUID: String] = [:]
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    
    /// Distinct countries present in the loaded pods, alphabetically —
    /// drives the "Preferred pods - <Country>" sections on Home.
    var countries: [String] {
        Array(Set(pods.map { $0.country })).sorted()
    }
    
    private init() {}
    
    func fetchPods() async {
        isLoading = true
        defer { isLoading = false }
        do {
            pods = try await supabase
                .from("pods")
                .select()
                .order("name")
                .execute()
                .value
            await fetchPrimaryPhotos()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    /// Loads just the first photo (position 0) per pod — enough for the
    /// Home cards. The full carousel is fetched separately on the detail
    /// screen, not needed for the list view.
    private func fetchPrimaryPhotos() async {
        do {
            let photos: [PodPhotoRow] = try await supabase
                .from("pod_photos")
                .select("pod_id, url, position")
                .eq("position", value: 0)
                .execute()
                .value
            primaryPhotoByPodId = photos.reduce(into: [:]) { result, photo in
                result[photo.podId] = photo.url  // last one wins, never crashes on duplicates
            }
        } catch {
            // Non-fatal — cards just show the placeholder if this fails.
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
    
    /// Fetched on demand per pod — not needed for the Home cards, only
    /// when opening a pod's detail screen.
    func rooms(forPodId podId: UUID) async -> [PodRoom] {
        do {
            return try await supabase
                .from("pod_rooms")
                .select()
                .eq("pod_id", value: podId)
                .order("position")
                .execute()
                .value
        } catch {
            lastError = error.localizedDescription
            return []
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
        do {
            let rows: [PodPhotoRow] = try await supabase
                .from("pod_photos")
                .select("pod_id, url, position")
                .eq("pod_id", value: podId)
                .order("position")
                .execute()
                .value
            return rows.map { $0.url }
        } catch {
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

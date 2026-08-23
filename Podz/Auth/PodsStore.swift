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
    
    /// Distinct pod types present in the loaded data (e.g. "Refuge",
    /// "Bivouac") — drives the real category filter chips, replacing the
    /// old hardcoded "Hikes"/"Trails"/... placeholders.
    var podTypes: [String] {
        Array(Set(pods.map { $0.podType })).sorted()
    }
    
    func count(forType type: String) -> Int {
        pods.filter { $0.podType == type }.count
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
    
    /// Same as above, with an optional pod_type filter. Pass nil or "All"
    /// to skip filtering by type.
    func pods(inCountry country: String, type: String?) -> [Pod] {
        pods.filter { pod in
            pod.country == country && (type == nil || type == "All" || pod.podType == type)
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

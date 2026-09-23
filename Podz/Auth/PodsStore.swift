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
    
    /// Distinct countries present in the loaded pods, alphabetically —
    /// drives the "Preferred pods - <Country>" sections on Home.
    var countries: [String] {
        Array(Set(pods.map { $0.country })).sorted()
    }
    
    private init() {}
    
    /// Returns whether it succeeded — same reasoning as
    /// `ReservationsStore.fetchMine`'s own boolean return: `TripPassStore`
    /// needs to tell a real fetch failure apart from a genuinely empty
    /// result before it overwrites its own disk cache.
    @discardableResult
    func fetchPods() async -> Bool {
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
            return true
        } catch {
            lastError = error.localizedDescription
            return false
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
    
    /// Creates a pod owned by the current host — requires `is_host` on
    /// their profile (see SQL/host_accounts.sql's insert policy; a
    /// non-host's insert is rejected server-side, not just hidden client-
    /// side). Inserts the pod row first, then uploads each photo to
    /// Storage and inserts the resulting `pod_photos` rows — same
    /// JPEG-compression + per-user/per-item path pattern as
    /// `PostsStore.createPost`. A photo upload failing partway through
    /// doesn't fail the whole call — the pod itself is already real at
    /// that point, so this returns it regardless and just logs
    /// `lastError` for whichever photo didn't make it, rather than
    /// leaving the host with no pod at all over a flaky photo. Returns
    /// the inserted pod on success and appends it to `pods` locally, same
    /// shape as `ReservationsStore.create`.
    ///
    /// Needs a public `pod-photos` Storage bucket to exist already — same
    /// as `avatars`/`post-photos`, neither of which has a tracked SQL
    /// migration either (both created directly in the Supabase dashboard),
    /// so this one needs the same one-time manual setup.
    ///
    /// `scannedModelURL`, when present, is a local `.usdz` file from a
    /// host's in-app LiDAR scan (see `PodScanCaptureView`) — uploaded to
    /// its own `pod-models` bucket (same one-time manual setup as
    /// `pod-photos`) and written to `pods.model_url` via an update, not an
    /// insert column, for the same reason photos are a separate step: it
    /// needs `inserted.id` for the storage path, which doesn't exist until
    /// after the pod row itself is created. See SQL/pod_3d_models.sql for
    /// the column and the update policy this needs.
    @discardableResult
    func createPod(_ insert: PodInsert, images: [UIImage] = [], scannedModelURL: URL? = nil) async -> Pod? {
        lastError = nil
        do {
            var inserted: Pod = try await supabase
                .from("pods")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
            pods.append(inserted)

            for (index, image) in images.enumerated() {
                guard let jpegData = image.jpegData(compressionQuality: 0.8) else { continue }
                let path = "\(insert.hostId.uuidString.lowercased())/\(inserted.id.uuidString.lowercased())/\(index).jpg"
                do {
                    try await supabase.storage
                        .from("pod-photos")
                        .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
                    let publicURL = try supabase.storage.from("pod-photos").getPublicURL(path: path)
                    try await supabase
                        .from("pod_photos")
                        .insert(PodPhotoInsert(podId: inserted.id, url: publicURL.absoluteString, position: index))
                        .execute()
                    if index == 0 {
                        primaryPhotoByPodId[inserted.id] = publicURL.absoluteString
                    }
                } catch {
                    lastError = error.localizedDescription
                }
            }

            if let scannedModelURL {
                do {
                    let modelData = try Data(contentsOf: scannedModelURL)
                    let path = "\(insert.hostId.uuidString.lowercased())/\(inserted.id.uuidString.lowercased())/model.usdz"
                    try await supabase.storage
                        .from("pod-models")
                        .upload(path, data: modelData, options: FileOptions(contentType: "model/vnd.usdz+zip", upsert: true))
                    let publicURL = try supabase.storage.from("pod-models").getPublicURL(path: path)
                    try await supabase
                        .from("pods")
                        .update(["model_url": publicURL.absoluteString])
                        .eq("id", value: inserted.id)
                        .execute()
                    inserted.modelURL = publicURL.absoluteString
                    if let podsIndex = pods.firstIndex(where: { $0.id == inserted.id }) {
                        pods[podsIndex].modelURL = publicURL.absoluteString
                    }
                } catch {
                    lastError = error.localizedDescription
                }
            }

            return inserted
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Deletes one of *your own* pods (optimistic) — requires
    /// `pod.hostId` to match the current user both here and, redundantly
    /// but not just for show, server-side via the `.eq("host_id", ...)`
    /// on the delete itself (an insert policy alone in
    /// SQL/host_accounts.sql doesn't cover delete; RLS defaults to deny,
    /// so this is already blocked there regardless of what this client
    /// sends, but scoping the query too keeps the intent explicit). Rooms
    /// and reservations aren't declared with `on delete cascade` anywhere
    /// this repo tracks (`pods`/`pod_rooms` predate SQL/ entirely), so
    /// this deletes `pod_photos`/`pod_rooms`/`reservations` for the pod
    /// first, then the pod row itself — same ordering a cascade would
    /// give you, just explicit. Storage files are cleaned up afterward,
    /// best-effort (listing whatever's actually in
    /// `<hostId>/<podId>/`, not a locally-tracked count) — same reasoning
    /// as `PostsStore.deletePost`: the DB delete is what actually makes
    /// the pod gone, so a Storage cleanup failure just leaves orphaned
    /// files rather than a stuck or incorrectly-restored pod.
    func deletePod(_ pod: Pod) async {
        guard let userId = AuthManager.shared.session?.user.id, pod.hostId == userId else { return }
        let previousPods = pods
        let previousPhoto = primaryPhotoByPodId[pod.id]

        pods.removeAll { $0.id == pod.id }
        primaryPhotoByPodId.removeValue(forKey: pod.id)

        do {
            try await supabase.from("pod_photos").delete().eq("pod_id", value: pod.id).execute()
            try await supabase.from("pod_rooms").delete().eq("pod_id", value: pod.id).execute()
            try await supabase.from("reservations").delete().eq("pod_id", value: pod.id).execute()
            try await supabase
                .from("pods")
                .delete()
                .eq("id", value: pod.id)
                .eq("host_id", value: userId)
                .execute()

            let prefix = "\(userId.uuidString.lowercased())/\(pod.id.uuidString.lowercased())"
            if let files = try? await supabase.storage.from("pod-photos").list(path: prefix), !files.isEmpty {
                try? await supabase.storage.from("pod-photos").remove(paths: files.map { "\(prefix)/\($0.name)" })
            }
        } catch {
            pods = previousPods
            if let previousPhoto { primaryPhotoByPodId[pod.id] = previousPhoto }
            lastError = error.localizedDescription
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

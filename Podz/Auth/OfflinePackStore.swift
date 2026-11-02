import Foundation
import Combine
import CoreLocation
import UIKit

/// Keeps what you'll need up there on the phone: for every hut you've liked or
/// have a stay at, its photos (the first four), a satellite map of the spot and
/// its details, so it opens with no signal. Runs quietly when the app is open
/// and there's a connection; a failed download is simply tried again next time.
@MainActor
final class OfflinePackStore: ObservableObject {
    static let shared = OfflinePackStore()

    /// The huts saved on the phone.
    @Published private(set) var savedPodIds: Set<UUID>
    private var isSyncing = false
    private let maxHuts = 60
    private let photosPerHut = 4

    private init() {
        let saved = OfflineStorage.load([UUID].self, named: "pack-saved") ?? []
        savedPodIds = Set(saved)
    }

    func isSaved(_ podId: UUID) -> Bool { savedPodIds.contains(podId) }

    /// Saves what's missing for the liked huts and the upcoming stays.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let upcoming = ReservationsStore.shared.reservations.filter(\.isUpcoming).map(\.podId)
        let wanted = Array(Set(LikesStore.shared.likes.keys).union(upcoming))
        let pods = PodsStore.shared.pods.filter { wanted.contains($0.id) }.prefix(maxHuts)

        var saved = savedPodIds
        for pod in pods {
            if Task.isCancelled { return }
            if await save(pod) { saved.insert(pod.id) }
        }
        // Huts you no longer like or have a stay at drop out of the list (their
        // files are kept: they're small and may be useful again).
        saved.formIntersection(wanted)
        savedPodIds = saved
        OfflineStorage.save(Array(saved), as: "pack-saved")
    }

    /// Photos, details and the map for one hut. True when it's all on the phone.
    private func save(_ pod: Pod) async -> Bool {
        let rows = await PodsStore.shared.photoRows(forPodId: pod.id)
        var photosOK = true
        for row in rows.prefix(photosPerHut) {
            photosOK = await ImageCache.shared.keepForOffline(urlString: row.url) && photosOK
        }
        var mapOK = true
        if let coordinate = pod.coordinate {
            mapOK = await MapSnapshotCache.shared.keepForOffline(coordinate)
        }
        return photosOK && mapOK
    }
}

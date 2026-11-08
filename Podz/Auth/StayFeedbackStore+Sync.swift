import Foundation
import Supabase
internal import Auth

/// The account's copy of the stay answers and photos (`SQL/sync_plans_and_stays.sql`):
/// a `stay_feedback` row per stay, the photos in the private `stay-photos`
/// bucket under `<user id>/<reservation id>/`. Everything stays local first;
/// this catches up in the background and fails silently (no signal, tables not
/// there yet), so the traveler never waits on it.
extension StayFeedbackStore {
    /// What this phone knows about the account's copy: which photos are up
    /// there (so one missing from the row was deleted somewhere else) and which
    /// deletions still have to be told.
    struct SyncState: Codable {
        var uploaded: Set<String> = []
        var pendingDeletes: Set<String> = []
    }

    /// A row of `stay_feedback`.
    private struct Row: Codable {
        let reservationId: UUID
        let userId: UUID
        let mood: StayFeedback.Mood?
        let photos: [String]
        let answeredAt: Date

        enum CodingKeys: String, CodingKey {
            case mood, photos
            case reservationId = "reservation_id"
            case userId = "user_id"
            case answeredAt = "answered_at"
        }
    }

    /// "<reservation id>/<file name>": how a photo is named in the sync state.
    static func photoKey(_ reservation: UUID, _ name: String) -> String {
        "\(reservation.uuidString)/\(name)"
    }

    /// Only the app's own file names come back from the account: a name with a
    /// path in it never gets written to disk.
    private static func isSafe(_ name: String) -> Bool {
        name.hasSuffix(".jpg") && !name.contains("/") && !name.contains("..")
    }

    private func remotePath(_ user: UUID, _ reservation: UUID, _ name: String) -> String {
        "\(user.uuidString.lowercased())/\(reservation.uuidString.lowercased())/\(name)"
    }

    /// Brings this phone's answers and the account's together: answers and
    /// photos only here go up, the ones only there come down, and a photo
    /// deleted on either side goes from the other.
    func sync() async {
        reload()
        guard let userId = AuthManager.shared.session?.user.id else { return }
        // Something changed while a round was running: go again after it.
        if isSyncing {
            syncAgain = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            syncAgain = false
            await syncOnce(userId)
        } while syncAgain
    }

    private func syncOnce(_ userId: UUID) async {
        let bucket = supabase.storage.from("stay-photos")
        let remote: [Row]
        do {
            remote = try await supabase.from("stay_feedback")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
        } catch {
            return
        }
        let remoteById = Dictionary(remote.map { ($0.reservationId, $0) }, uniquingKeysWith: { first, _ in first })

        // Photos deleted here: tell the bucket (and don't bring them back).
        let deleting = syncState.pendingDeletes
        for key in deleting {
            let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2, let reservation = UUID(uuidString: parts[0]) else {
                syncState.pendingDeletes.remove(key)
                continue
            }
            do {
                _ = try await bucket.remove(paths: [remotePath(userId, reservation, parts[1])])
            } catch {
                continue
            }
            syncState.pendingDeletes.remove(key)
            syncState.uploaded.remove(key)
        }

        for local in Array(entries.values) {
            await syncEntry(local, remote: remoteById[local.id], userId: userId, bucket: bucket, deleting: deleting)
        }

        // Answers only the account has (another phone, or a reinstall).
        for row in remote where entries[row.reservationId] == nil {
            var photos: [String] = []
            for name in row.photos where Self.isSafe(name) && photos.count < Self.maxPhotosPerStay {
                let key = Self.photoKey(row.reservationId, name)
                guard !deleting.contains(key),
                      await download(bucket, userId, row.reservationId, name) else { continue }
                photos.append(name)
                syncState.uploaded.insert(key)
            }
            entries[row.reservationId] = StayFeedback(id: row.reservationId, mood: row.mood, photos: photos, answeredAt: row.answeredAt)
            // Already answered somewhere else: no need to ask here.
            if row.reservationId == pendingStay?.id { finish() }
        }
        write()
    }

    private func syncEntry(_ local: StayFeedback, remote: Row?, userId: UUID, bucket: StorageFileApi, deleting: Set<String>) async {
        let id = local.id
        var mood = local.mood
        var answeredAt = local.answeredAt
        var dropped: [String] = []
        var downloaded: [String] = []
        var uploadedNow: [String] = []

        if let remote {
            // The account has a newer answer.
            if remote.mood != local.mood, remote.answeredAt > local.answeredAt.addingTimeInterval(1) {
                mood = remote.mood
                answeredAt = remote.answeredAt
            }
            // Photos that went up from here and have left the row: deleted elsewhere.
            for name in local.photos
            where !remote.photos.contains(name) && syncState.uploaded.contains(Self.photoKey(id, name)) {
                dropped.append(name)
            }
            // Photos from another phone.
            for name in remote.photos
            where Self.isSafe(name) && !local.photos.contains(name) {
                let key = Self.photoKey(id, name)
                guard !syncState.uploaded.contains(key), !deleting.contains(key),
                      local.photos.count - dropped.count + downloaded.count < Self.maxPhotosPerStay,
                      await download(bucket, userId, id, name) else { continue }
                downloaded.append(name)
                syncState.uploaded.insert(key)
            }
        }

        // Photos only here go up.
        if let folder = photoFolder(for: id) {
            for name in local.photos where !dropped.contains(name) && !syncState.uploaded.contains(Self.photoKey(id, name)) {
                guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)),
                      (try? await bucket.upload(remotePath(userId, id, name), data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))) != nil
                else { continue }
                uploadedNow.append(name)
            }
        }

        // The row lists what is up there.
        let listed = local.photos.filter { name in
            !dropped.contains(name) && (uploadedNow.contains(name) || syncState.uploaded.contains(Self.photoKey(id, name)))
        } + downloaded
        if remote == nil || remote?.mood != mood || Set(remote?.photos ?? []) != Set(listed) {
            let row = Row(reservationId: id, userId: userId, mood: mood, photos: listed, answeredAt: answeredAt)
            if (try? await supabase.from("stay_feedback").upsert(row).execute()) != nil {
                for name in uploadedNow { syncState.uploaded.insert(Self.photoKey(id, name)) }
            }
        } else {
            for name in uploadedNow { syncState.uploaded.insert(Self.photoKey(id, name)) }
        }

        // What changed here meanwhile (the traveler may have added a photo
        // during the round) stays: only the deltas are applied.
        guard var current = entries[id] else { return }
        if mood != local.mood {
            current.mood = mood
            current.answeredAt = answeredAt
        }
        if let folder = photoFolder(for: id) {
            for name in dropped { try? FileManager.default.removeItem(at: folder.appendingPathComponent(name)) }
        }
        current.photos.removeAll { dropped.contains($0) }
        for name in downloaded where !current.photos.contains(name) { current.photos.append(name) }
        entries[id] = current
    }

    private func download(_ bucket: StorageFileApi, _ userId: UUID, _ reservation: UUID, _ name: String) async -> Bool {
        guard let folder = photoFolder(for: reservation),
              let data = try? await bucket.download(path: remotePath(userId, reservation, name)),
              data.starts(with: [0xFF, 0xD8, 0xFF])
        else { return false }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (try? data.write(to: folder.appendingPathComponent(name), options: .atomic)) != nil
    }
}

import Foundation
import Combine
import Supabase
internal import Auth

/// The plans the user saved, kept on the phone (one file per account, in
/// Application Support), newest first, and copied to the account
/// (`SQL/sync_plans_and_stays.sql`) so they survive a reinstall and follow to a
/// new phone.
///
/// Local first: the list on screen is always the file, saving and deleting are
/// instant, and the copy catches up in the background. If the tables aren't
/// there yet, or there's no signal, nothing changes for the user; it tries again
/// next time (`sync()`, at launch and when the app comes back).
@MainActor
final class SavedPlansStore: ObservableObject {
    static let shared = SavedPlansStore()

    @Published private(set) var plans: [SavedPlan] = []
    private var loadedFor: String?
    private var syncState = SyncState()
    private var isSyncing = false

    /// What the account's copy knows about this phone's list: which plans have
    /// gone up (so one missing from the account was deleted somewhere else) and
    /// which deletions still have to be told.
    private struct SyncState: Codable {
        var synced: Set<UUID> = []
        var pendingDeletes: Set<UUID> = []
    }

    /// A row of `saved_plans`.
    private struct Row: Codable {
        let id: UUID
        let userId: UUID
        let title: String
        let payload: SavedPlan
        let savedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, title, payload
            case userId = "user_id"
            case savedAt = "saved_at"
        }
    }

    private var accountKey: String {
        AuthManager.shared.session?.user.id.uuidString ?? "local"
    }

    private func fileURL(_ name: String) -> URL? {
        guard let folder = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        return folder.appendingPathComponent("\(name)-\(accountKey).json")
    }

    /// Reads the file again when the account changed.
    func reload() {
        guard loadedFor != accountKey else { return }
        loadedFor = accountKey
        syncState = fileURL("saved-plans-sync")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(SyncState.self, from: $0) } ?? SyncState()
        guard let file = fileURL("saved-plans"), let data = try? Data(contentsOf: file),
              let saved = try? JSONDecoder().decode([SavedPlan].self, from: data)
        else {
            plans = []
            return
        }
        plans = saved.sorted { $0.savedAt > $1.savedAt }
    }

    func add(_ plan: SavedPlan) {
        reload()
        plans.insert(plan, at: 0)
        write()
        Task { await sync() }
    }

    func remove(_ plan: SavedPlan) {
        reload()
        plans.removeAll { $0.id == plan.id }
        syncState.pendingDeletes.insert(plan.id)
        write()
        Task { await sync() }
    }

    /// The saved plan with these huts in this order, if there is one.
    func plan(withPods podIds: [UUID]) -> SavedPlan? {
        plans.first { $0.podIds == podIds }
    }

    /// Forgets the signed-out account's plans from memory (they stay in their file).
    func clear() {
        plans = []
        loadedFor = nil
        syncState = SyncState()
    }

    private func write() {
        if let file = fileURL("saved-plans"), let data = try? JSONEncoder().encode(plans) {
            try? data.write(to: file, options: .atomic)
        }
        if let file = fileURL("saved-plans-sync"), let data = try? JSONEncoder().encode(syncState) {
            try? data.write(to: file, options: .atomic)
        }
    }

    // MARK: - The account's copy

    /// Brings this phone's list and the account's together. Plans only here go
    /// up, plans only there come down, and a deletion made on either side
    /// reaches the other. Failures are silent: the local list is the truth on
    /// screen.
    func sync() async {
        reload()
        guard !isSyncing, let userId = AuthManager.shared.session?.user.id else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let remote: [Row] = try await supabase
                .from("saved_plans")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // Deletions made here: tell the account, and leave those rows out
            // of what follows.
            let deleting = syncState.pendingDeletes
            for id in deleting {
                try await supabase.from("saved_plans").delete().eq("id", value: id).execute()
                syncState.pendingDeletes.remove(id)
                syncState.synced.remove(id)
            }
            let remoteIds = Set(remote.map(\.id)).subtracting(deleting)

            // Plans only the account has: bring them down.
            let localIds = Set(plans.map(\.id))
            for row in remote where !localIds.contains(row.id) && !deleting.contains(row.id) {
                plans.append(row.payload)
                syncState.synced.insert(row.id)
            }

            // Plans only here: one that went up before was deleted elsewhere
            // (take it off), a new one goes up.
            for plan in plans where !remoteIds.contains(plan.id) && localIds.contains(plan.id) {
                if syncState.synced.contains(plan.id) {
                    plans.removeAll { $0.id == plan.id }
                    syncState.synced.remove(plan.id)
                } else {
                    try await supabase.from("saved_plans")
                        .upsert(Row(id: plan.id, userId: userId, title: plan.title, payload: plan, savedAt: plan.savedAt))
                        .execute()
                    syncState.synced.insert(plan.id)
                }
            }
            for id in remoteIds { syncState.synced.insert(id) }

            plans.sort { $0.savedAt > $1.savedAt }
            write()
        } catch {
            // No signal, or the tables aren't there yet: the local list stands.
            write()
        }
    }
}

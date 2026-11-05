import Foundation
import Combine
internal import Auth

/// The plans the user saved, kept on the phone (one file per account, in
/// Application Support), newest first.
@MainActor
final class SavedPlansStore: ObservableObject {
    static let shared = SavedPlansStore()

    @Published private(set) var plans: [SavedPlan] = []
    private var loadedFor: String?

    private var accountKey: String {
        AuthManager.shared.session?.user.id.uuidString ?? "local"
    }

    private var file: URL? {
        guard let folder = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        return folder.appendingPathComponent("saved-plans-\(accountKey).json")
    }

    /// Reads the file again when the account changed.
    func reload() {
        guard loadedFor != accountKey else { return }
        loadedFor = accountKey
        guard let file, let data = try? Data(contentsOf: file),
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
    }

    func remove(_ plan: SavedPlan) {
        reload()
        plans.removeAll { $0.id == plan.id }
        write()
    }

    /// The saved plan with these huts in this order, if there is one.
    func plan(withPods podIds: [UUID]) -> SavedPlan? {
        plans.first { $0.podIds == podIds }
    }

    private func write() {
        guard let file, let data = try? JSONEncoder().encode(plans) else { return }
        try? data.write(to: file, options: .atomic)
    }
}

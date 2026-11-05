import Foundation

/// Files the app keeps for the mountains, where there's often no signal. They
/// live in Application Support (not Caches, which iOS may empty) and are left
/// out of backups: it's all copies of what the server has.
enum OfflineStorage {
    nonisolated static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var directory = base.appendingPathComponent("PodzOffline", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        return directory
    }()

    nonisolated static func subdirectory(_ name: String) -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// `personal` (your reservations, likes, folders, passes) also asks iOS
    /// to keep the file encrypted while the phone is locked, unless the app
    /// already has it open.
    nonisolated static func save<T: Encodable>(_ value: T, as name: String, personal: Bool = false) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        var options: Data.WritingOptions = [.atomic]
        if personal { options.insert(.completeFileProtectionUnlessOpen) }
        try? data.write(to: directory.appendingPathComponent(name + ".json"), options: options)
    }

    /// What was kept for one account, removed when it signs out on this phone.
    nonisolated static func removeFiles(of userId: UUID) {
        for prefix in ["reservations", "likes", "folders"] {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(prefix)-\(userId.uuidString).json"))
        }
    }

    nonisolated static func load<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name + ".json")) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

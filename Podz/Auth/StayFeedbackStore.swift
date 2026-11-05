import Foundation
import Combine
import UIKit
internal import Auth

/// Lenny asks how a stay went once it is over, and keeps the answer and the
/// photos on the phone (one file per account in Application Support; the photos
/// in a folder per stay). Nothing is sent anywhere.
///
/// It asks once per stay, for the most recent one that ended in the last two
/// weeks. Answering, or saying "Not now", closes it for good.
@MainActor
final class StayFeedbackStore: ObservableObject {
    static let shared = StayFeedbackStore()

    /// Every answer given, by reservation id.
    @Published private(set) var entries: [UUID: StayFeedback] = [:]
    /// The stay Lenny is asking about right now.
    @Published private(set) var pendingStay: Reservation?
    @Published private(set) var askNow = false

    private var loadedFor: String?
    /// A stay that ended longer ago than this isn't asked about any more.
    private let shelfLife: TimeInterval = 14 * 24 * 3600
    static let maxPhotosPerStay = 12

    private init() {}

    // MARK: - Asking

    /// Looks for a finished stay nobody has been asked about, and if there is
    /// one starts asking. Safe to call as often as needed.
    func check() {
        reload()
        guard !askNow, !HutContactTracker.shared.askNow else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let candidate = ReservationsStore.shared.reservations
            .filter { stay in
                guard stay.status == "confirmed", entries[stay.id] == nil,
                      let end = Reservation.date(from: stay.checkOut)
                else { return false }
                return end < today && today.timeIntervalSince(end) < shelfLife
            }
            .max { (Reservation.date(from: $0.checkOut) ?? .distantPast) < (Reservation.date(from: $1.checkOut) ?? .distantPast) }
        guard let candidate else { return }
        pendingStay = candidate
        askNow = true
    }

    /// The traveler said how it went.
    func answer(_ mood: StayFeedback.Mood) {
        guard let id = pendingStay?.id else { return }
        var entry = entries[id] ?? StayFeedback(id: id, mood: mood, photos: [], answeredAt: Date())
        entry.mood = mood
        entry.answeredAt = Date()
        entries[id] = entry
        write()
    }

    /// "Not now": closes the question without an answer, so it isn't asked again.
    func skip() {
        if let id = pendingStay?.id, entries[id] == nil {
            entries[id] = StayFeedback(id: id, mood: nil, photos: [], answeredAt: Date())
            write()
        }
        finish()
    }

    /// Done asking (answered or not): the page goes back to normal.
    func finish() {
        askNow = false
        pendingStay = nil
    }

    /// Forgets the signed-out account's answers from memory.
    func clear() {
        entries = [:]
        loadedFor = nil
        finish()
    }

    // MARK: - Photos

    func photoCount(for id: UUID) -> Int { entries[id]?.photos.count ?? 0 }

    func photoURLs(for id: UUID) -> [URL] {
        guard let folder = photoFolder(for: id) else { return [] }
        return (entries[id]?.photos ?? []).map { folder.appendingPathComponent($0) }
    }

    /// Keeps a photo with the stay. Returns whether it was kept.
    @discardableResult
    func addPhoto(_ jpeg: Data, to id: UUID) -> Bool {
        guard photoCount(for: id) < Self.maxPhotosPerStay, let folder = photoFolder(for: id) else { return false }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString).jpg"
        guard (try? jpeg.write(to: folder.appendingPathComponent(name), options: .atomic)) != nil else { return false }
        var entry = entries[id] ?? StayFeedback(id: id, mood: nil, photos: [], answeredAt: Date())
        entry.photos.append(name)
        entries[id] = entry
        write()
        return true
    }

    /// A photo from the library, shrunk to at most 1600 on its longest side
    /// and compressed, so a stay's photos stay a few MB.
    nonisolated static func jpeg(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longest, 1))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Files

    private var accountKey: String {
        AuthManager.shared.session?.user.id.uuidString ?? "local"
    }

    private var support: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    private var file: URL? { support?.appendingPathComponent("stay-feedback-\(accountKey).json") }

    private func photoFolder(for id: UUID) -> URL? {
        support?.appendingPathComponent("StayFeedback", isDirectory: true).appendingPathComponent(id.uuidString, isDirectory: true)
    }

    /// Reads the file again when the account changed.
    func reload() {
        guard loadedFor != accountKey else { return }
        loadedFor = accountKey
        guard let file, let data = try? Data(contentsOf: file),
              let saved = try? JSONDecoder().decode([StayFeedback].self, from: data)
        else {
            entries = [:]
            return
        }
        entries = Dictionary(saved.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func write() {
        guard let file, let data = try? JSONEncoder().encode(Array(entries.values)) else { return }
        try? data.write(to: file, options: .atomic)
    }
}

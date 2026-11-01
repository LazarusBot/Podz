import Foundation
import Combine

/// Remembers that the traveler went to contact a listed hut (call, email,
/// website) so that, when they come back to the app, Lenny can ask whether they
/// booked it and offer to add the stay to their reservations.
///
/// Kept on the phone: nothing is sent anywhere. It asks once per contact, after
/// the app has actually been left (a call that is cancelled at the system's
/// confirmation never leaves the app, so it doesn't ask).
@MainActor
final class HutContactTracker: ObservableObject {
    static let shared = HutContactTracker()

    /// The hut the traveler went to contact.
    @Published private(set) var pendingPodId: UUID?
    /// Lenny should ask now: the traveler is back.
    @Published private(set) var askNow = false
    /// The traveler said yes from Home's prompt: the pod opens and the dates
    /// are asked straight away.
    @Published private(set) var accepted = false

    private var leftTheApp = false
    private let defaults = UserDefaults.standard
    private let podKey = "hutContact.podId"
    private let dateKey = "hutContact.date"
    /// A contact older than this isn't asked about any more.
    private let shelfLife: TimeInterval = 7 * 24 * 3600

    private init() {
        if let string = defaults.string(forKey: podKey), let id = UUID(uuidString: string),
           let date = defaults.object(forKey: dateKey) as? Date, Date().timeIntervalSince(date) < shelfLife {
            pendingPodId = id
            // The app was closed since: the first time it's active, ask.
            leftTheApp = true
        } else {
            clear()
        }
    }

    /// The traveler chose to call, email or visit this hut's website.
    func didContact(_ pod: Pod) {
        guard !pod.isBookable else { return }
        pendingPodId = pod.id
        askNow = false
        leftTheApp = false
        defaults.set(pod.id.uuidString, forKey: podKey)
        defaults.set(Date(), forKey: dateKey)
    }

    /// "Yes, I booked it", answered away from the hut's own page.
    func accept() { accepted = true }

    func appWentToBackground() {
        if pendingPodId != nil { leftTheApp = true }
    }

    func appBecameActive() {
        guard pendingPodId != nil, leftTheApp else { return }
        leftTheApp = false
        askNow = true
    }

    /// Answered (booked and added, or not yet): stop asking.
    func clear() {
        pendingPodId = nil
        askNow = false
        accepted = false
        leftTheApp = false
        defaults.removeObject(forKey: podKey)
        defaults.removeObject(forKey: dateKey)
    }
}

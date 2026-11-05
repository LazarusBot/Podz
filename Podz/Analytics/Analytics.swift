import Foundation
import UIKit
import Supabase

/// What the app records about how it's used, so a TestFlight round says where
/// people get stuck. Built to stay small and private (`design.md`, Privacy):
///
/// - **First party**: rows go to Podz's own Supabase (`SQL/analytics.sql`), no
///   third-party SDK, no tracking, nothing leaves for an ad network.
/// - **Anonymous**: an install id (a random UUID made on this phone), never
///   the account, e-mail or name. A search's words are never recorded, only
///   that one happened and how many pods it found.
/// - **Light**: events wait in a small queue and go in batches (every 10, and
///   when the app goes to the background). With no signal they are kept on
///   the phone and go later.
///
/// Turn it off with `Analytics.isEnabled = false`.
@MainActor
final class Analytics {
    static let shared = Analytics()

    /// Every event the app can send: a closed list, so a typo can't make a
    /// new one up.
    enum Event: String {
        case appOpen = "app_open"
        case signedUp = "signed_up"
        case loggedIn = "logged_in"
        case codeFailed = "code_failed"
        case podOpened = "pod_opened"
        case bookTapped = "book_tapped"
        case hutContactTapped = "hut_contact_tapped"
        case externalBookingStarted = "external_booking_started"
        case reservationBooked = "reservation_booked"
        case reservationFailed = "reservation_failed"
        case lennySearch = "lenny_search"
        case podLiked = "pod_liked"
        case folderCreated = "folder_created"
    }

    private struct Row: Codable {
        let installId: UUID
        let sessionId: UUID
        let name: String
        let props: [String: String]
        let occurredAt: String
        let appVersion: String
        let build: String
        let os: String
        let locale: String
        let isDebug: Bool

        enum CodingKeys: String, CodingKey {
            case installId = "install_id", sessionId = "session_id", name, props
            case occurredAt = "occurred_at", appVersion = "app_version", build, os, locale
            case isDebug = "is_debug"
        }
    }

    private static let enabledKey = "analytics.enabled"
    private static let installKey = "analytics.installId"
    private static let queueFile = "analytics_queue"
    private static let batchSize = 10
    /// A phone that stays offline for days doesn't grow the queue forever.
    private static let queueLimit = 500

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Made once per install, kept in UserDefaults; gone with the app.
    static var installId: UUID {
        if let text = UserDefaults.standard.string(forKey: installKey), let id = UUID(uuidString: text) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: installKey)
        return id
    }

    private let sessionId = UUID()
    private var queue: [Row] = OfflineStorage.load([Row].self, named: Analytics.queueFile) ?? []
    private var isFlushing = false
    private let timestamp = ISO8601DateFormatter()

    private init() {}

    /// Called once at launch: counts the open, sends what's left from last
    /// time, and flushes whenever the app goes to the background.
    func start() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushInBackground() }
        }
        track(.appOpen)
        Task { await flush() }
    }

    func track(_ event: Event, _ props: [String: String] = [:]) {
        guard Self.isEnabled else { return }
        let info = Bundle.main.infoDictionary
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        queue.append(Row(
            installId: Self.installId,
            sessionId: sessionId,
            name: event.rawValue,
            props: props,
            occurredAt: timestamp.string(from: Date()),
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?",
            os: UIDevice.current.systemVersion,
            locale: Bundle.main.preferredLocalizations.first ?? "en",
            isDebug: isDebug
        ))
        if queue.count > Self.queueLimit { queue.removeFirst(queue.count - Self.queueLimit) }
        if queue.count >= Self.batchSize { Task { await flush() } }
    }

    func flush() async {
        guard Self.isEnabled, !isFlushing, !queue.isEmpty else { return }
        isFlushing = true
        defer { isFlushing = false }
        let batch = Array(queue.prefix(50))
        do {
            try await supabase.from("app_events").insert(batch).execute()
            queue.removeFirst(min(batch.count, queue.count))
            if !queue.isEmpty { Task { await flush() } }
        } catch is PostgrestError {
            // The server read the batch and refused it (a row over the limits
            // in SQL/security_hardening.sql): sending it again never works,
            // so it goes instead of blocking the queue.
            queue.removeFirst(min(batch.count, queue.count))
        } catch {
            // No signal, or the table isn't there yet: keep them for later.
        }
        persist()
    }

    private func persist() {
        OfflineStorage.save(queue, as: Self.queueFile)
    }

    /// Gets a last batch out while iOS still gives the app a moment.
    private func flushInBackground() {
        persist()
        let holder = BackgroundTask()
        holder.id = UIApplication.shared.beginBackgroundTask { [holder] in
            MainActor.assumeIsolated { UIApplication.shared.endBackgroundTask(holder.id) }
        }
        Task {
            await flush()
            UIApplication.shared.endBackgroundTask(holder.id)
        }
    }
}

/// Carries the background task's id into its own expiry handler.
private final class BackgroundTask: @unchecked Sendable {
    var id = UIBackgroundTaskIdentifier.invalid
}

import Foundation
import MetricKit
import Supabase

/// Crash reports, without a third-party SDK: iOS itself (MetricKit) hands the
/// app a report of any crash, hang or runaway CPU/disk use, by the next launch
/// after it happened. Each one goes to Podz's own Supabase (`app_diagnostics`,
/// `SQL/analytics.sql`) with the install id, version and OS, nothing about
/// the person. TestFlight and App Store Connect also show Apple's own crash
/// list; this one is the full call stack where it matters.
///
/// A report arrives only once, so it's saved on the phone first and removed
/// when it has been sent.
final class DiagnosticsReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = DiagnosticsReporter()

    private struct Row: Codable {
        let installId: UUID
        let appVersion: String
        let build: String
        let os: String
        let summary: String
        let payload: String

        enum CodingKeys: String, CodingKey {
            case installId = "install_id", appVersion = "app_version", build, os, summary, payload
        }
    }

    private nonisolated static let pendingFile = "diagnostics_pending"
    private let lock = NSLock()

    /// Called once at launch.
    func start() {
        MXMetricManager.shared.add(self)
        Task { await send() }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let info = Bundle.main.infoDictionary
        let installId = UserDefaults.standard.string(forKey: "analytics.installId").flatMap(UUID.init(uuidString:)) ?? UUID()
        let rows = payloads.map { payload in
            Row(
                installId: installId,
                appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
                build: info?["CFBundleVersion"] as? String ?? "?",
                os: ProcessInfo.processInfo.operatingSystemVersionString,
                summary: "crashes \(payload.crashDiagnostics?.count ?? 0), hangs \(payload.hangDiagnostics?.count ?? 0), cpu \(payload.cpuExceptionDiagnostics?.count ?? 0), disk \(payload.diskWriteExceptionDiagnostics?.count ?? 0)",
                payload: String(data: payload.jsonRepresentation(), encoding: .utf8) ?? ""
            )
        }
        lock.withLock {
            OfflineStorage.save((OfflineStorage.load([Row].self, named: Self.pendingFile) ?? []) + rows, as: Self.pendingFile)
        }
        Task { await send() }
    }

    private func send() async {
        guard Analytics.isEnabled else { return }
        let rows = OfflineStorage.load([Row].self, named: Self.pendingFile) ?? []
        guard !rows.isEmpty else { return }
        do {
            try await supabase.from("app_diagnostics").insert(rows).execute()
            // Keep anything that arrived while this was going.
            lock.withLock {
                let now = OfflineStorage.load([Row].self, named: Self.pendingFile) ?? []
                OfflineStorage.save(Array(now.dropFirst(rows.count)), as: Self.pendingFile)
            }
        } catch {
            // Stays on the phone for the next launch.
        }
    }
}

//
//  DeepLinkRouter.swift
//  Podz
//
//  Created by Max Prx on 26/08/2026.
//

import Foundation
import Combine

/// Handles `podz://pod/<uuid>` links (the old share card wrote them; nothing
/// in the app writes them today, but a link someone kept still opens the
/// pod) — parses the incoming URL and holds the target pod id until Home
/// (`MinimalHomeView`) can resolve it against `PodsStore` and navigate.
///
/// Custom URL scheme, not a Universal Link — this only opens the app if
/// it's already installed on the recipient's device (no website/App
/// Store fallback). Universal Links would need a real domain hosting an
/// apple-app-site-association file plus an Associated Domains
/// entitlement, neither of which exist for this project yet.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    @Published var pendingPodId: UUID?

    private init() {}

    /// Only exactly `podz://pod/<uuid>` is taken (any app or web page can
    /// open a `podz://` link): one path part, a well-formed UUID, nothing
    /// else. Anything unknown is ignored.
    func handle(_ url: URL) {
        guard url.absoluteString.count <= 200,
              url.scheme?.lowercased() == "podz", url.host?.lowercased() == "pod",
              url.query == nil, url.fragment == nil, url.user == nil
        else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 1, let id = UUID(uuidString: parts[0]) else { return }
        pendingPodId = id
    }
}

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

    func handle(_ url: URL) {
        guard url.scheme == "podz", url.host == "pod" else { return }
        guard let id = UUID(uuidString: url.lastPathComponent) else { return }
        pendingPodId = id
    }
}

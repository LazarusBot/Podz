import Foundation
import Combine

/// Whether Home's search pill is expanded (focused) — shared so
/// `MainTabView` can hide the floating tab bar while it's open, the
/// same way it already does for Lenny's editing phase.
@MainActor
final class HomeSearchState: ObservableObject {
    static let shared = HomeSearchState()

    @Published var isExpanded = false

    private init() {}
}

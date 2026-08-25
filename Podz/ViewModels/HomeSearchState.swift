import Foundation
import Combine

/// Whether Home's search pill is expanded (focused) — shared so
/// `MainTabView` can hide the floating tab bar while it's open, the
/// same way it already does for Lenny's editing phase.
@MainActor
final class HomeSearchState: ObservableObject {
    static let shared = HomeSearchState()

    @Published var isExpanded = false

    /// Bumped by BottomTabBar whenever "Feed" is tapped while it's
    /// already the active tab — HomeView observes this to pop back out
    /// of a pod detail and collapse search, the same "tap the tab again
    /// to go home" pattern most apps use. A plain counter, not a Bool:
    /// tapping it twice in a row with nothing else changing in between
    /// should still fire the reset both times.
    @Published var feedReselected = 0

    private init() {}
}

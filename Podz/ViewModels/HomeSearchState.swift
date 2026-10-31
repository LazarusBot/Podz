import Foundation
import Combine

/// Home's tab bar signals, shared across screens.
@MainActor
final class HomeSearchState: ObservableObject {
    static let shared = HomeSearchState()

    /// Bumped by MinimalTabBar whenever "Feed" is tapped while it's
    /// already the active tab — HomeView observes this to pop back out
    /// of a pod detail and collapse search, the same "tap the tab again
    /// to go home" pattern most apps use. A plain counter, not a Bool:
    /// tapping it twice in a row with nothing else changing in between
    /// should still fire the reset both times.
    @Published var feedReselected = 0

    private init() {}
}

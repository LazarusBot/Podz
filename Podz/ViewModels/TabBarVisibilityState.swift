import Foundation
import Combine

/// Whether `MainTabView`'s floating bar should be hidden: a page with its own
/// pill row at the bottom (a Likes folder, the pages Profile opens) asks the
/// bar to step aside for as long as it's on screen.
@MainActor
final class TabBarVisibilityState: ObservableObject {
    static let shared = TabBarVisibilityState()

    @Published var isHidden = false

    private init() {}
}

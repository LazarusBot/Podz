import Foundation
import Combine

/// Whether the screen currently showing in a tab that is otherwise forced
/// light has been designed for dark mode (see `MainTabView`). A screen opts
/// in for as long as it's on screen — Profile's main screen does, the older
/// screens it leads to (friends, posts, edit profile…) don't yet.
@MainActor
final class AppearanceState: ObservableObject {
    static let shared = AppearanceState()

    @Published var followsSystem = false

    private init() {}
}

import Foundation
import Combine

/// Whether the screen currently showing in a tab that is otherwise forced
/// light has been designed for dark mode (see `MainTabView`). A screen opts
/// in for as long as it's on screen — the Likes folder view does, the Likes
/// overview behind it doesn't yet.
@MainActor
final class AppearanceState: ObservableObject {
    static let shared = AppearanceState()

    @Published var followsSystem = false

    private init() {}
}

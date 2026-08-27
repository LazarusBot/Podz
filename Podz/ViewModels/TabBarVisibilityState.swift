import Foundation
import Combine

/// Whether `MainTabView`'s floating bar should be hidden — most sub-
/// screens deliberately leave it visible underneath (PodDetailView,
/// ProfileEditView), but FriendsView's floating "+" add-friend button
/// sits right where the tab bar draws on top of it, blocking taps. Shared
/// so any screen can opt out for as long as it's on screen.
@MainActor
final class TabBarVisibilityState: ObservableObject {
    static let shared = TabBarVisibilityState()

    @Published var isHidden = false

    private init() {}
}

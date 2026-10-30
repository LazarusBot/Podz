import Foundation
import Combine

/// Asks the Profile tab to open one of its pages from somewhere else (Lenny's
/// plan sends you to your reservations once they're booked). The tab bar
/// switches to Profile when the request is made; ProfileView opens the page
/// and clears the request.
@MainActor
final class ProfileRouter: ObservableObject {
    static let shared = ProfileRouter()

    @Published var showsReservationsRequested = false

    private init() {}
}

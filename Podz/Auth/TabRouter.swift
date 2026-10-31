import Foundation
import Combine

/// Asks the tabs to do something from somewhere else. The tab bar switches
/// to the right tab when a request is made; the screen there acts on it and
/// clears it.
@MainActor
final class TabRouter: ObservableObject {
    static let shared = TabRouter()

    /// Open Profile > Reservations (Lenny's plan sends you there once booked).
    @Published var showsReservationsRequested = false
    /// Go to Home with Lenny's search open (the empty Reservations page).
    @Published var lennyRequested = false

    private init() {}
}

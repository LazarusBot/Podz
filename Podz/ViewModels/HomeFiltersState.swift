import Foundation
import Combine

/// Home's Filters panel state — shared so `HomeView` can read the values
/// to actually filter the feed, not just display them in
/// `HomeSearchRow`'s inline panel.
///
/// `hikers`, `checkIn`, `checkOut`, `wifi`, and `pets` are all live UI
/// controls, but only `hikers` currently affects results: `pods` has a
/// `bedsTotal` column to filter on, while wifi/pets/availability have no
/// backing data yet (no columns on `pods`, no bookings table). Once
/// those exist, wire their filtering in the same place `hikers` is
/// applied in `HomeView`.
@MainActor
final class HomeFiltersState: ObservableObject {
    static let shared = HomeFiltersState()

    private static let defaultCheckIn = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    private static let defaultCheckOut = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    /// Whether the Filters panel is open — shared (rather than local
    /// state in HomeSearchRow) since HomeView also needs to read it.
    @Published var isExpanded = false

    /// True right after a Check-in/Checkout DatePicker is tapped open.
    /// Its native calendar overlay renders outside the search pill's own
    /// tap-absorbing bounds, so the tap that closes it (tapping anywhere
    /// outside the calendar) was escaping to HomeView's global
    /// tap-outside-to-dismiss and closing the whole pill instead of just
    /// the calendar. HomeView consumes this flag — suppresses exactly
    /// one outside tap, then resets it — rather than suppressing the
    /// global dismiss for as long as filters happen to be open, so tap-
    /// outside still closes the panel normally once no picker is
    /// mid-interaction.
    @Published var datePickerActive = false

    /// 0 = no filter, matches the Hikers stepper's own "unset" state.
    @Published var hikers: Int = 0
    @Published var checkIn: Date = HomeFiltersState.defaultCheckIn
    @Published var checkOut: Date = HomeFiltersState.defaultCheckOut
    @Published var wifi: Bool = true
    @Published var pets: Bool = true

    /// What `checkIn`/`checkOut` are considered "unchanged" against —
    /// lets the confirm button next to each DatePicker gray itself out
    /// until the user actually changes something, rather than always
    /// looking tappable. Tapping that button moves this up to match the
    /// now-confirmed value, so it grays back out again until the next
    /// real change instead of staying permanently enabled.
    @Published var initialCheckIn = HomeFiltersState.defaultCheckIn
    @Published var initialCheckOut = HomeFiltersState.defaultCheckOut

    private init() {}
}

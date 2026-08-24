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

    /// 0 = no filter, matches the Hikers stepper's own "unset" state.
    @Published var hikers: Int = 0
    @Published var checkIn: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @Published var checkOut: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @Published var wifi: Bool = true
    @Published var pets: Bool = true

    private init() {}
}

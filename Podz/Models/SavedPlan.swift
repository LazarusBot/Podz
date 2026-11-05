import Foundation

/// A plan Lenny made, kept to come back to (Profile > Plans) without booking:
/// the huts picked at each stop, in order, and the answers given so far.
struct SavedPlan: Codable, Identifiable, Equatable {
    struct Stop: Codable, Equatable {
        let name: String
        let podId: UUID
        /// "24 beds · showers", as the summary showed it.
        let detail: String
        let isPick: Bool
    }

    let id: UUID
    var title: String
    let savedAt: Date
    let isLoop: Bool
    /// A walking route across an area (its stops show the day from the last hut).
    let isRoute: Bool
    let stops: [Stop]
    var guests: Int?
    var startDate: Date?
    var nights: Int?

    var podIds: [UUID] { stops.map(\.podId) }
}

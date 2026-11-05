import Foundation

/// What the traveler told Lenny about a stay that is over: how it went and the
/// photos they kept. Kept on the phone, keyed by the reservation.
struct StayFeedback: Codable, Identifiable, Equatable {
    enum Mood: String, Codable {
        case good
        case bad
    }

    /// The reservation this is about.
    let id: UUID
    /// nil when the question was skipped: it isn't asked twice.
    var mood: Mood?
    /// File names inside the stay's photo folder.
    var photos: [String]
    var answeredAt: Date
}

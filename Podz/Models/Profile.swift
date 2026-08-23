import Foundation

/// Mirrors a row in the `profiles` table (see SQL/001_profiles.sql).
struct Profile: Codable, Equatable {
    let id: UUID
    var age: Int?
    var location: String?
    var username: String?
    var fullName: String?
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case age
        case location
    }

    /// Falls back gracefully when Apple sign-in hasn't provided a name yet.
    var displayName: String { fullName ?? username ?? "Guest" }
}

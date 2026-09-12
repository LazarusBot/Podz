import Foundation

/// Mirrors a row in the `profiles` table (see SQL/001_profiles.sql).
struct Profile: Codable, Equatable {
    let id: UUID
    var age: Int?
    var location: String?
    var username: String?
    var fullName: String?
    var avatarURL: String?
    /// Header/cover photo behind ProfileEditView's own top bar — see
    /// SQL/profile_header_photo.sql. Nil until a user sets one, in which
    /// case ProfileEditView falls back to a generic decorative photo.
    var headerPhotoURL: String?
    /// Whether this user can create/manage pods — see SQL/host_accounts.sql.
    /// Not optional: the column is `not null default false`, so every row
    /// always has a value once that migration's been run (same assumption
    /// every other non-optional field here already makes about its own
    /// column).
    var isHost: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case headerPhotoURL = "header_photo_url"
        case age
        case location
        case isHost = "is_host"
    }

    /// Falls back gracefully when Apple sign-in hasn't provided a name yet.
    var displayName: String { fullName ?? username ?? "Guest" }
}

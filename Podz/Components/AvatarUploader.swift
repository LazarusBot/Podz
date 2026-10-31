import Foundation
import Storage
import Supabase

/// Sends a profile photo to Supabase Storage and points the profile at it.
/// Shared by the photo picker and the photo editor.
enum AvatarUploader {
    /// Uploads `jpeg` as the current user's avatar. Throws on failure.
    @MainActor
    static func upload(jpeg: Data) async throws {
        guard let userId = AuthManager.shared.session?.user.id else {
            throw NSError(domain: "Avatar", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active session."])
        }
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"

        try await supabase.storage
            .from("avatars")
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg", upsert: true))

        let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)

        // Cache-bust so the new photo shows immediately instead of a stale
        // cached version at the same URL.
        let bustedURL = "\(publicURL.absoluteString)?t=\(Date().timeIntervalSince1970)"
        await AuthManager.shared.updateProfile(avatarURL: bustedURL)
    }
}

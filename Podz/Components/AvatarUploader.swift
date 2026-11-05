import Foundation
import UIKit
import Storage
import Supabase

/// Sends a profile photo to Supabase Storage and points the profile at it.
/// Shared by the photo picker and the photo editor.
enum AvatarUploader {
    /// The bucket should refuse anything bigger too (`SQL/security_hardening.sql`).
    static let maxBytes = 2_000_000
    /// An avatar never needs more than this on its longest side.
    private static let maxSide: CGFloat = 1024

    /// A picked photo made avatar-sized: a 48 MP original becomes a light
    /// JPEG instead of going up whole.
    static func jpeg(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }

    /// Uploads `jpeg` as the current user's avatar. Throws on failure.
    @MainActor
    static func upload(jpeg: Data) async throws {
        guard let userId = AuthManager.shared.session?.user.id else {
            throw NSError(domain: "Avatar", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active session."])
        }
        // Only a real JPEG (it starts FF D8 FF) of a sensible size goes up.
        guard jpeg.count <= maxBytes, jpeg.starts(with: [0xFF, 0xD8, 0xFF]) else {
            throw NSError(domain: "Avatar", code: 2, userInfo: [NSLocalizedDescriptionKey: "That photo is too large."])
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

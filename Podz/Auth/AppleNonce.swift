import Foundation
import CryptoKit

/// Apple recommends passing a nonce with every Sign in with Apple request
/// so the returned identity token can't be replayed. Supabase's
/// `signInWithIdToken` verifies it too, so both sides need the same value:
/// - the SHA256 hash goes into `ASAuthorizationAppleIDRequest.nonce`
/// - the raw (unhashed) value goes to `AuthManager.signInWithApple`
enum AppleNonce {
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

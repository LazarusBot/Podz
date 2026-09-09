import Foundation
import Supabase
import Combine

/// Central place for all auth logic. Your views never call `supabase.auth`
/// directly — they call methods here, which keeps `LoginView` / `RegisterView`
/// / etc. exactly as they are today, just swapping their TODOs for real calls.
///
/// Session persistence (staying logged in between app launches) is handled
/// automatically by the Supabase SDK via the Keychain — you don't need to
/// manage that yourself.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published private(set) var session: Session?
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published private(set) var profile: Profile?
    @Published private(set) var isInitializing = true
    /// Set on a successful `signUp`, cleared once the post-register
    /// onboarding has been shown. In-memory only (not @AppStorage) — this
    /// is intentional, see the PodzApp.swift routing note about the old
    /// hasSeenOnboarding bug.
    @Published private(set) var justRegistered = false

    var isAuthenticated: Bool { session != nil }
    
    private var authStateTask: Task<Void, Never>?
    /// Safety-net timer for the case below — cancelled the moment a real
    /// follow-up event arrives, so it only ever fires if the background
    /// refresh never resolves at all.
    private var expiredSessionFallbackTask: Task<Void, Never>?

    private init() {
        // Restores any existing session at launch, then keeps `session`
        // in sync automatically whenever it changes (sign in, sign out,
        // token refresh...). Also (re)loads the profile row whenever we
        // go from signed-out to signed-in, and clears it on sign-out.
        authStateTask = Task {
            for await (_, session) in supabase.auth.authStateChanges {
                // With emitLocalSessionAsInitialSession, the very first
                // emission may be an expired locally-cached session, which
                // the SDK then refreshes in the background on its own.
                // Previously this branch treated that first emission as an
                // immediate sign-out, which flipped the UI to the auth
                // screen for the split second before the refreshed session
                // landed — the "login page appears and disappears" flash.
                // Instead, stay on the launch skeleton and wait for that
                // resolved event, with a short timeout rather than hanging
                // on the skeleton forever if the SDK's own background
                // refresh never resolves.
                if isInitializing, let session, session.isExpired {
                    expiredSessionFallbackTask?.cancel()
                    expiredSessionFallbackTask = Task {
                        try? await Task.sleep(for: .seconds(6))
                        guard !Task.isCancelled else { return }
                        // A refresh that never resolves within the timeout
                        // is most often just "no network right now," not
                        // "this token is actually invalid" — the SDK
                        // swallows both cases identically, with no way to
                        // tell them apart from here. Signing out on that
                        // ambiguity would strand anyone offline (exactly
                        // the case this app's own offline trip pass exists
                        // for — see TripPassView/TripPassStore) on a login
                        // screen they also can't get past with no signal.
                        // Keep the stale session and let them in instead;
                        // any live Supabase call this expired token can't
                        // cover just fails the same way every other
                        // network failure already does in this app
                        // (lastError set, cached data left alone).
                        self.session = session
                        self.isInitializing = false
                        await self.fetchProfile()
                    }
                    continue
                }
                expiredSessionFallbackTask?.cancel()
                self.session = session
                if session != nil {
                    await self.fetchProfile()
                } else {
                    self.profile = nil
                }
                isInitializing = false
            }
        }
    }

    deinit {
        authStateTask?.cancel()
        expiredSessionFallbackTask?.cancel()
    }
    
    // MARK: - Profile
    
    /// Loads the current user's row from `public.profiles`. Called
    /// automatically after sign in / sign up / app launch with an existing
    /// session — you generally don't need to call this yourself, except
    /// after updating the profile (e.g. from a "Personal information"
    /// edit screen) to refresh the cached copy.
    func fetchProfile() async {
        guard let userId = session?.user.id else { return }
        do {
            profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
        } catch {
            // Common right after Apple sign-in on a brand new account: the
            // trigger runs on insert, so there's a brief window where the
            // row may not exist yet. Not fatal — profile just stays nil
            // and the UI falls back to "Guest" until the next fetch.
            lastError = error.localizedDescription
        }
    }
    
    /// Update your own profile (e.g. from a settings screen). `username`
    /// must stay unique — a duplicate will throw, so surface `lastError`
    /// to the user if you call this from a form.
    func updateProfile(username: String? = nil, fullName: String? = nil, avatarURL: String? = nil, age: Int? = nil, location: String? = nil) async {
        guard let userId = session?.user.id else {
            lastError = "No active session — can't update profile."
            return
        }
        var updates: [String: AnyJSON] = [:]
        if let username { updates["username"] = .string(username) }
        if let fullName { updates["full_name"] = .string(fullName) }
        if let avatarURL { updates["avatar_url"] = .string(avatarURL) }
        if let age { updates["age"] = .integer(age) }
        if let location { updates["location"] = .string(location) }
        guard !updates.isEmpty else {
            lastError = "Nothing to update — value was empty or couldn't be parsed."
            return
        }
        
        do {
            try await supabase
                .from("profiles")
                .update(updates)
                .eq("id", value: userId)
                .execute()
            await fetchProfile()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    /// Flips the current user into a host — see SQL/host_accounts.sql for
    /// the column this writes and the policy that then lets them insert
    /// pods. Idempotent: calling it again once already a host just
    /// re-confirms the same state, nothing special-cased either way.
    @discardableResult
    func becomeHost() async -> Bool {
        guard let userId = session?.user.id else {
            lastError = "No active session — can't become a host."
            return false
        }
        do {
            try await supabase
                .from("profiles")
                .update(["is_host": AnyJSON.bool(true)])
                .eq("id", value: userId)
                .execute()
            await fetchProfile()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Email / password
    
    func signUp(name: String, username: String, email: String, password: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await supabase.auth.signUp(
                email: email,
                password: password,
                data: [
                    "full_name": .string(name),
                    "username": .string(username)
                ]
            )
            justRegistered = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Call once the post-register onboarding has been shown/dismissed.
    func finishPostRegisterOnboarding() {
        justRegistered = false
    }
    
    /// `identifier` is whatever's typed into Login's single field — an
    /// email straight through, or a username resolved server-side first
    /// (see SQL/get_email_for_username.sql) to the email Supabase Auth
    /// actually signs in with. Auth itself only ever knows email/password;
    /// this is the one place username gets translated into that.
    func signIn(identifier: String, password: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let email = try await resolvedEmail(for: identifier)
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// A bare heuristic ("@" present) is enough here — this only decides
    /// whether to skip the username lookup, not whether the string is a
    /// well-formed email; an actually-malformed email still reaches
    /// `supabase.auth.signIn` unchanged and fails there with its own
    /// normal error, same as always.
    private func resolvedEmail(for identifier: String) async throws -> String {
        guard !identifier.contains("@") else { return identifier }
        let email: String? = try await supabase
            .rpc("get_email_for_username", params: ["p_username": identifier])
            .execute()
            .value
        guard let email else {
            throw UsernameLookupError.notFound
        }
        return email
    }

    /// Sends a password reset email. Returns whether it succeeded so the
    /// caller can show a confirmation — failure is already surfaced via
    /// `lastError`.
    @discardableResult
    func resetPassword(email: String) async -> Bool {
        lastError = nil
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Sign in with Apple
    
    /// Called from `AppleSignInCoordinator.onSuccess` with the identity
    /// token Apple returned, plus the raw nonce you generated before
    /// starting the Apple request (see `AppleNonce.swift`).
    func signInWithApple(idToken: String, rawNonce: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
            )
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    // MARK: - Delete / sign out
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            // Whoever signs in next (possibly a different account)
            // starts in hiker mode, not whatever this session had
            // switched to — see AppModeStore's own doc comment.
            AppModeStore.shared.reset()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    func deleteAccount() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.rpc("delete_own_account").execute()
            try await supabase.auth.signOut()
        } catch {
            lastError = error.localizedDescription
        }
    }
}

private enum UsernameLookupError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: "No account found for that username."
        }
    }
}

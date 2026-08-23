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
    
    var isAuthenticated: Bool { session != nil }
    
    private var authStateTask: Task<Void, Never>?
    
    private init() {
        // Restores any existing session at launch, then keeps `session`
        // in sync automatically whenever it changes (sign in, sign out,
        // token refresh...). Also (re)loads the profile row whenever we
        // go from signed-out to signed-in, and clears it on sign-out.
        authStateTask = Task {
            var receivedFirstEvent = false
            for await (_, session) in supabase.auth.authStateChanges {
                // With emitLocalSessionAsInitialSession, the very first
                // emission may be an expired locally-cached session —
                // treat that as signed-out rather than authenticated.
                if let session, session.isExpired {
                    self.session = nil
                    self.profile = nil
                    if !receivedFirstEvent { isInitializing = false; receivedFirstEvent = true }
                    continue
                }
                self.session = session
                if session != nil {
                    await self.fetchProfile()
                } else {
                    self.profile = nil
                }
                if !receivedFirstEvent { isInitializing = false; receivedFirstEvent = true }
            }
        }
    }
    
    deinit {
        authStateTask?.cancel()
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
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            lastError = error.localizedDescription
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

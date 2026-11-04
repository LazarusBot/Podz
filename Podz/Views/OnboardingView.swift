import SwiftUI
import UIKit

/// OnboardingView.swift — the app's root view. It routes between the launch
/// screen (Lenny asking for a moment, then "all good" and a way in), the onboarding flow (see Onboarding/OnboardingFlow.swift,
/// email-code sign-in) and the signed-in app, driven by
/// `AuthManager.isAuthenticated` which stays in sync automatically with
/// the real Supabase session. A brand-new account stays in the onboarding
/// for its intro steps, gated by `AuthManager.justRegistered` — a returning
/// user skips straight to the app.
///
/// This is also the single point that decides hiker shell vs. host
/// shell — `HostTabView` shows only when both `Profile.isHost` (the
/// account actually has hosting unlocked) and `AppModeStore`'s `mode`
/// (which side they last switched to, flippable anytime from either
/// shell's own Profile tab — see ProfileView's "Hosting" section) agree.
/// A non-host always lands in `MainTabView` regardless of what `mode`
/// holds, so a stale/leftover `.host` value from a previous account
/// can't strand a plain hiker account on a shell they have no access to.
///
/// The hiker↔host swap itself is a plain instant cut, deliberately — an
/// earlier version covered it with a full-screen curtain (`ModeSwitchPill`'s
/// long-press-and-slide gesture in the tab bar is already its own "moment"
/// for the switch, and Airbnb's own hosting/traveling toggle treats the
/// swap itself as plumbing, not something worth a second flourish on top).
struct OnboardingView: View {
    @StateObject private var auth = AuthManager.shared
    /// Lenny's line gets its moment even when the session resolves at once.
    @StateObject private var beat = LennyBeat()
    /// The launch screen is left by its own caption, never on its own.
    @State private var launchDone = false
    /// The huts are in (fetched, or the wait ran out): Lenny won't say "all
    /// good" before, so Home opens with its cards.
    @State private var podsLoaded = false

    var body: some View {
        Group {
            if !launchDone {
                LaunchWaitingView(
                    isReady: !auth.isInitializing && !beat.isHolding && podsLoaded,
                    goesHome: auth.isAuthenticated && !auth.justRegistered,
                    onContinue: { launchDone = true }
                )
            } else if auth.isAuthenticated && !auth.justRegistered {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .task {
            beat.start()
            // The pods load now, under Lenny's first line; a slow or failing
            // network gives up after 8 s so the screen is never stuck.
            Task {
                await PodsStore.shared.fetchPods()
                podsLoaded = true
            }
            try? await Task.sleep(for: .seconds(8))
            podsLoaded = true
        }
        // Appearance is decided per screen: the launch screen, the onboarding,
        // Home, Likes and the pod detail follow the system; everything else has no dark
        // palette yet and stays light (this used to be a global
        // `UIUserInterfaceStyle = Light` in Info.plist).
    }
}

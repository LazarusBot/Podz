import SwiftUI
import UIKit

/// OnboardingView.swift — the app's root view. It routes between the launch
/// screen (Lenny asking for a moment), the onboarding flow (see Onboarding/OnboardingFlow.swift,
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

    var body: some View {
        Group {
            if auth.isInitializing {
                LaunchWaitingView()
                    .preferredColorScheme(.light)
            } else if auth.isAuthenticated && !auth.justRegistered {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        // Appearance is decided per screen: the onboarding, Home, Likes and
        // the pod detail follow the system; everything else has no dark
        // palette yet and stays light (this used to be a global
        // `UIUserInterfaceStyle = Light` in Info.plist).
    }
}

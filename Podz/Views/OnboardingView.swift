import SwiftUI
import UIKit

/// OnboardingView.swift — the app's root view. It routes between the launch
/// screen (Lenny asking for a moment, then "all good" and a way in), the onboarding flow (see Onboarding/OnboardingFlow.swift,
/// email-code sign-in) and the signed-in app, driven by
/// `AuthManager.isAuthenticated` which stays in sync automatically with
/// the real Supabase session. A brand-new account stays in the onboarding
/// for its intro steps, gated by `AuthManager.justRegistered` — a returning
/// user skips straight to the app (`MainTabView`).
struct OnboardingView: View {
    @StateObject private var auth = AuthManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Lenny's line gets its moment even when the session resolves at once.
    @StateObject private var beat = LennyBeat()
    /// The launch screen (signed-in users only) is left by its own caption,
    /// never on its own.
    @State private var launchDone = false
    /// Lenny's bubbles are leaving (a beat before the ground fades).
    @State private var launchLeaving = false
    /// The huts are in (fetched, or the wait ran out): Lenny won't say "all
    /// good" before, so Home opens with its cards.
    @State private var podsLoaded = false
    /// The signed-in user's first name, kept from the last launch so Lenny
    /// can use it from the first frame (the profile arrives a moment later).
    @AppStorage("launchFirstName") private var firstName = ""

    /// Lenny's screen is for a signed-in user, until they tap in.
    private var showsLaunch: Bool {
        !auth.isInitializing && !launchDone && auth.isAuthenticated && !auth.justRegistered
    }

    /// Home is in place once Lenny's screen is gone (or was never there).
    private var homeSettled: Bool { !showsLaunch }

    /// The bubbles drift down and fade, then the ground dissolves while Home
    /// settles in under it.
    private func leaveLaunch() {
        guard !launchLeaving else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.3)) { launchLeaving = true }
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeInOut(duration: 0.8)) { launchDone = true }
        }
    }

    var body: some View {
        ZStack {
            if auth.isInitializing {
                // The session isn't known yet: a plain ground, so a signed-out
                // user goes straight to the onboarding, with no Lenny.
                Color.onbBackground.ignoresSafeArea()
            } else if auth.isAuthenticated && !auth.justRegistered {
                // Already there under Lenny's screen, so leaving it is a fade
                // onto Home rather than a cut.
                MainTabView()
                    // Under Lenny's screen it waits slightly too close and out
                    // of focus; when the screen goes, it pulls back into place
                    // and sharpens, so the arrival is felt.
                    .scaleEffect(homeSettled || reduceMotion ? 1 : 1.07)
                    .blur(radius: homeSettled ? 0 : 14)
                    .animation(.easeOut(duration: 1.0), value: homeSettled)
            } else {
                OnboardingFlow()
            }

            if showsLaunch {
                LaunchWaitingView(
                    isReady: !beat.isHolding && podsLoaded,
                    isLeaving: launchLeaving,
                    firstName: firstName.isEmpty ? nil : firstName,
                    onContinue: leaveLaunch
                )
                .transition(.opacity)
            }
        }
        .onChange(of: auth.profile?.fullName, initial: true) { _, fullName in
            // The first word of the name; kept until the next launch.
            if let first = fullName?.split(separator: " ").first { firstName = String(first) }
        }
        .onChange(of: auth.isAuthenticated) { _, signedIn in
            if !signedIn && !auth.isInitializing { firstName = "" }
        }
        .onChange(of: auth.isInitializing, initial: true) { _, initializing in
            guard !initializing else { return }
            // Lenny's launch is for someone signed in; everyone else sees the
            // classic onboarding at once.
            guard auth.isAuthenticated else { launchDone = true; return }
            beat.start()
            // The pods load now, under Lenny's first line; a slow or failing
            // network gives up after 8 s so the screen is never stuck.
            Task {
                await PodsStore.shared.fetchPods()
                podsLoaded = true
            }
            Task {
                try? await Task.sleep(for: .seconds(8))
                podsLoaded = true
            }
        }
        // Appearance is decided per screen: the launch screen, the onboarding,
        // Home, Likes and the pod detail follow the system; everything else has no dark
        // palette yet and stays light (this used to be a global
        // `UIUserInterfaceStyle = Light` in Info.plist).
    }
}

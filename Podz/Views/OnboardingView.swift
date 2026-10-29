import SwiftUI
import UIKit

/// OnboardingView.swift — the app's root view. It routes between the launch
/// placeholder, the onboarding flow (see Onboarding/OnboardingFlow.swift,
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
    @StateObject private var appMode = AppModeStore.shared

    var body: some View {
        Group {
            if auth.isInitializing {
                LaunchLoadingView()
                    .preferredColorScheme(.light)
            } else if auth.isAuthenticated && !auth.justRegistered {
                if auth.profile?.isHost == true && appMode.mode == .host {
                    HostTabView()
                } else {
                    MainTabView()
                }
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

/// Shown for the brief moment between app launch and the auth state
/// resolving — replaces what was previously a blank white flash while
/// `session` sat at its default `nil` before authStateChanges emitted
/// anything. Echoes HomeView's own layout (header, search pill, a row of
/// pod cards) as gray placeholder shapes, so launch reads as "your feed is
/// arriving" rather than a generic spinner.
private struct LaunchLoadingView: View {
    /// Same sizing as `PodSection.cardSize` — two cards on screen plus a
    /// sliver of a third peeking at the trailing edge.
    private var cardSize: CGFloat {
        (UIScreen.main.bounds.width - 24 - 2 * 12 - 24) / 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonShape(cornerRadius: AppRadius.r4).frame(width: 90, height: 12)
                    SkeletonShape(cornerRadius: AppRadius.r5).frame(width: 130, height: 20)
                }
                Spacer()
                SkeletonShape(cornerRadius: AppRadius.r21).frame(width: 42, height: 42)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            SkeletonShape(cornerRadius: AppRadius.r26)
                .frame(height: 52)
                .padding(.horizontal, 24)

            SkeletonShape(cornerRadius: AppRadius.r5)
                .frame(width: 170, height: 18)
                .padding(.leading, 24)
                .padding(.top, 28)
                .padding(.bottom, 12)

            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonShape(cornerRadius: AppRadius.r18).frame(width: cardSize, height: cardSize)
                        SkeletonShape(cornerRadius: AppRadius.r4).frame(width: cardSize * 0.55, height: 14)
                            .padding(.leading, 5)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
    }
}

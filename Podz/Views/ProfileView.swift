//
//  ProfileView.swift
//  Podz
//
//  Created by Max Prx on 13/08/2026.
//

import SwiftUI
internal import Auth

/// The minimalist Profile: a big title, who you are, one pill to edit it, a
/// short list of where else to go, and log out / delete account at the end.
/// The pages it leads to are built on `SectionPage`.
struct ProfileView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var friendsStore = FriendsStore.shared
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var router = TabRouter.shared
    @StateObject private var reservationsStore = ReservationsStore.shared
    @State private var showEditProfile = false
    @State private var showsAvatarEditor = false
    @State private var showFriends = false
    @State private var showReservations = false
    @State private var showLoginSecurity = false
    @State private var showAbout = false
    @State private var showDeleteAccountConfirmation = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if showEditProfile {
                ProfileEditView(onBack: { showEditProfile = false })
            } else if showFriends {
                FriendsView(onBack: { showFriends = false })
            } else if showReservations {
                MyReservationsView(onBack: { showReservations = false })
            } else if showLoginSecurity {
                LoginSecurityView(onBack: { showLoginSecurity = false })
            } else if showAbout {
                AboutView(onBack: { showAbout = false })
            } else {
                main
            }
        }
        .background(Color.homeBackground.ignoresSafeArea())
        // Everything under Profile follows the system appearance, and the
        // pages it opens have their own bottom bar, so the tab bar steps
        // aside while one is showing.
        .onAppear {
            AppearanceState.shared.followsSystem = true
            openRequestedPage()
        }
        .onChange(of: router.showsReservationsRequested) { _, _ in openRequestedPage() }
        .onDisappear {
            AppearanceState.shared.followsSystem = false
            TabBarVisibilityState.shared.isHidden = false
        }
        .onChange(of: isShowingSection) { _, showing in
            TabBarVisibilityState.shared.isHidden = showing
        }
    }

    /// A page another screen asked for (Lenny's plan: your reservations).
    private func openRequestedPage() {
        guard router.showsReservationsRequested else { return }
        router.showsReservationsRequested = false
        showReservations = true
    }

    private var isShowingSection: Bool {
        showEditProfile || showFriends || showReservations || showLoginSecurity || showAbout
    }

    // MARK: - Main screen

    /// When the next stay starts, beside Reservations ("In 5 days"), so the
    /// trip is one glance away instead of behind a row. Nil with nothing ahead.
    private var nextTripCaption: String? {
        let starts = reservationsStore.reservations.filter(\.isUpcoming).compactMap { Reservation.date(from: $0.checkIn) }
        guard let next = starts.min() else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: next).day ?? 0
        switch days {
        case ..<0: return "Under way"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    private var main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                T("Profile")
                    .font(AppFont.semiBoldLabel(30))
                    .tracking(-0.6)
                    .foregroundColor(.homeText)
                    .padding(.horizontal, 24)
                    .padding(.top, 25)

                identity
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                DetailTextButton(title: "Edit profile") { showEditProfile = true }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                VStack(spacing: 0) {
                    ProfileListRow(title: "Friends") { showFriends = true }
                    ProfileListRow(title: "Reservations", caption: nextTripCaption) { showReservations = true }
                    ProfileListRow(title: "Login and security") { showLoginSecurity = true }
                    ProfileListRow(title: "About Podz") { showAbout = true }
                }
                .padding(.top, 36)

                VStack(spacing: 0) {
                    ProfileListRow(title: "Log out", isDestructive: true) {
                        Task { await AuthManager.shared.signOut() }
                    }
                    ProfileListRow(title: "Delete account", isDestructive: true) {
                        showDeleteAccountConfirmation = true
                    }
                }
                .padding(.top, 28)

                // Room so the last row doesn't hide behind the floating tab bar.
                Color.clear.frame(height: 120)
            }
        }
        .background(Color.homeBackground)
        .task { await friendsStore.fetchAll() }
        .task { await likesStore.fetchAll() }
        .alert(tr("Delete your account?"), isPresented: $showDeleteAccountConfirmation) {
            Button(tr("Cancel"), role: .cancel) {}
            Button(tr("Delete"), role: .destructive) {
                Task { await AuthManager.shared.deleteAccount() }
            }
        } message: {
            T("This permanently deletes your account, profile, and liked pods. This can't be undone.")
        }
    }

    /// The round photo and, beside it, who you are and how active.
    private var identity: some View {
        HStack(spacing: 18) {
            AvatarView(imageName: auth.profile?.avatarURL, size: 76)
                // Press and hold to adjust the current photo (zoom, move, turn).
                .onLongPressGesture(minimumDuration: 0.4) {
                    guard auth.profile?.avatarURL != nil else { return }
                    showsAvatarEditor = true
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: showsAvatarEditor) { _, shown in shown }
                .fullScreenCover(isPresented: $showsAvatarEditor) {
                    AvatarEditorView(imageURL: auth.profile?.avatarURL) { showsAvatarEditor = false }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(auth.profile?.displayName ?? "Guest")
                    .font(AppFont.semiBoldLabel(20))
                    .foregroundColor(.homeText)
                    .lineLimit(1)

                if let username = auth.profile?.username {
                    T("@\(username)")
                        .font(AppFont.regularLabel(14))
                        .foregroundColor(.homeSubtitle)
                }

                T("\(friendsStore.friends.count) friends · \(likesStore.likes.count) likes")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ProfileView()
}

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
    @StateObject private var postsStore = PostsStore.shared
    @StateObject private var friendsStore = FriendsStore.shared
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var appMode = AppModeStore.shared
    @State private var showEditProfile = false
    @State private var showFriends = false
    @State private var showMyPosts = false
    @State private var showReservations = false
    @State private var showLoginSecurity = false
    @State private var showAccessibility = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showAddPod = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if showEditProfile {
                ProfileEditView(onBack: { showEditProfile = false })
            } else if showFriends {
                FriendsView(onBack: { showFriends = false })
            } else if showMyPosts {
                MyPostsView(onBack: { showMyPosts = false })
            } else if showReservations {
                MyReservationsView(onBack: { showReservations = false })
            } else if showLoginSecurity {
                LoginSecurityView(onBack: { showLoginSecurity = false })
            } else if showAccessibility {
                AccessibilityView(onBack: { showAccessibility = false })
            } else {
                main
            }
        }
        .background(Color.homeBackground.ignoresSafeArea())
        // A sheet, not another full-screen push: this is a multi-step form
        // (see AddPodView's own `step`), "a focused task on top of Profile".
        // It has no dark palette yet.
        .sheet(isPresented: $showAddPod) {
            AddPodView()
                .preferredColorScheme(.light)
        }
        // Everything under Profile follows the system appearance, and the
        // pages it opens have their own bottom bar, so the tab bar steps
        // aside while one is showing.
        .onAppear { AppearanceState.shared.followsSystem = true }
        .onDisappear {
            AppearanceState.shared.followsSystem = false
            TabBarVisibilityState.shared.isHidden = false
        }
        .onChange(of: isShowingSection) { _, showing in
            TabBarVisibilityState.shared.isHidden = showing
        }
    }

    private var isShowingSection: Bool {
        showEditProfile || showFriends || showMyPosts || showReservations || showLoginSecurity || showAccessibility
    }

    // MARK: - Main screen

    private var main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Profile")
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
                    ProfileListRow(title: "Posts", badgeCount: postsActivityCount) { showMyPosts = true }
                    ProfileListRow(title: "Reservations") { showReservations = true }
                    hostingRow
                    ProfileListRow(title: "Login and security") { showLoginSecurity = true }
                    ProfileListRow(title: "Accessibility") { showAccessibility = true }
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
        .alert("Delete your account?", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await AuthManager.shared.deleteAccount() }
            }
        } message: {
            Text("This permanently deletes your account, profile, and liked pods. This can't be undone.")
        }
    }

    /// The round photo and, beside it, who you are and how active.
    private var identity: some View {
        HStack(spacing: 18) {
            AvatarView(imageName: auth.profile?.avatarURL, size: 76)

            VStack(alignment: .leading, spacing: 4) {
                Text(auth.profile?.displayName ?? "Guest")
                    .font(AppFont.semiBoldLabel(20))
                    .foregroundColor(.homeText)
                    .lineLimit(1)

                if let username = auth.profile?.username {
                    Text("@\(username)")
                        .font(AppFont.regularLabel(14))
                        .foregroundColor(.homeSubtitle)
                }

                Text("\(friendsStore.friends.count) friends · \(myPostsCount) posts · \(likesStore.likes.count) likes")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    /// A host switches between traveling and hosting from here (it used to
    /// be the tab bar's long-press); anyone else can become one — which
    /// also takes them straight into the pod form, since being a host only
    /// matters once there's a pod behind it.
    @ViewBuilder
    private var hostingRow: some View {
        if auth.profile?.isHost == true {
            ProfileListRow(
                title: appMode.mode == .host ? "Switch to traveler mode" : "Switch to host mode",
                showsChevron: false
            ) {
                appMode.mode = appMode.mode == .host ? .hiker : .host
            }
        } else {
            ProfileListRow(title: "Become a host") {
                Task { await AuthManager.shared.becomeHost() }
                showAddPod = true
            }
        }
    }

    // MARK: - Counts

    private var myPostsCount: Int {
        guard let userId = auth.session?.user.id else { return 0 }
        return postsStore.posts.filter { $0.authorId == userId }.count
    }

    private var postsActivityCount: Int {
        guard let userId = auth.session?.user.id else { return 0 }
        return postsStore.newActivityCount(onPostsAuthoredBy: userId)
    }
}

#Preview {
    ProfileView()
}

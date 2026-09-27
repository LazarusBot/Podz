//
//  ProfileView.swift
//  Podz
//
//  Created by Max Prx on 13/08/2026.
//

import SwiftUI
internal import Auth

/// node 3827:1368 — "Profile"
struct ProfileView: View {
    var onBack: (() -> Void)? = nil
    @StateObject private var auth = AuthManager.shared
    @StateObject private var postsStore = PostsStore.shared
    @StateObject private var friendsStore = FriendsStore.shared
    @StateObject private var likesStore = LikesStore.shared
    @State private var showEditProfile = false
    @State private var showFriends = false
    @State private var showMyPosts = false
    @State private var showReservations = false
    @State private var showLoginSecurity = false
    @State private var showAccessibility = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showAddPod = false
    /// contentOffset.y — 0 at rest, grows positive scrolling down. Same
    /// `onScrollGeometryChange` approach PodDetailView uses for its own
    /// persistent top bar.
    @State private var scrollOffset: CGFloat = 0

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
                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Room for the persistent top bar to float
                            // over — it's an overlay, not a sibling in
                            // this VStack, so content needs its own space
                            // reserved up top instead of sitting behind it.
                            Color.clear.frame(height: topBarHeight)

                            ProfileAccountRow(
                                name: auth.profile?.displayName ?? "Guest",
                                subtitle: accountSubtitle,
                                avatarImageName: auth.profile?.avatarURL,
                                avatarCornerRadius: 10,
                            ) {
                                showEditProfile = true
                            }

                            // Tapping this both makes the current user a
                            // host (is_host, see SQL/host_accounts.sql)
                            // and takes them straight into the pod form —
                            // no separate "you're now a host!" step, since
                            // becoming one only actually matters once
                            // there's a pod behind it. Always shown,
                            // regardless of `isHost` — matches this
                            // screen's other promo cards below, none of
                            // which hide themselves once acted on either.
                            PromoCard(
                                backgroundImageName: "Pod",
                                title: PromoCard.title(prefix: "Make your place a ", underlined: "Podz"),
                                subtitleLines: ["Set up easily and start earning from your home.", "It's free."],
                                onTap: {
                                    Task { await AuthManager.shared.becomeHost() }
                                    showAddPod = true
                                }
                            )

                            // Only while there's actually something to
                            // complete — unlike the cards above, showing
                            // this to someone whose profile is already
                            // filled in would be asking them to finish
                            // something that isn't unfinished.
                            if isProfileIncomplete {
                                PromoCard(
                                    backgroundImageName: "Hutte1",
                                    title: PromoCard.title(prefix: "Finish your ", underlined: "profile"),
                                    subtitleLines: ["Add a photo and a few details so hosts know who's booking."],
                                    onTap: { showEditProfile = true }
                                )
                            }

                            SectionLabel(title: "Social", trailing: "Kangchenjunga · 8,586m")
                            VStack(spacing: 0) {
                                ProfileMenuRow(icon: "person.2", title: "Friends") {
                                    showFriends = true
                                }
                                ProfileMenuRow(icon: "square.stack", title: "Posts", badgeCount: postsActivityCount) {
                                    showMyPosts = true
                                }
                                ProfileMenuRow(icon: "calendar", title: "Reservations") {
                                    showReservations = true
                                }
                            }

                            SectionLabel(title: "Account", trailing: "K2 · 8,611m")
                            VStack(spacing: 0) {
                                ProfileMenuRow(icon: "lock.shield", title: "Login and security") {
                                    showLoginSecurity = true
                                }
                                ProfileMenuRow(icon: "figure.roll", title: "Accessibility") {
                                    showAccessibility = true
                                }
                            }

                            SectionLabel(title: "Danger zone", trailing: "Everest · 8,849m")
                            VStack(spacing: 0) {
                                ProfileMenuRow(icon: "rectangle.portrait.and.arrow.right", title: "Log out", isDestructive: true) {
                                    Task { await AuthManager.shared.signOut() }
                                }
                                ProfileMenuRow(icon: "trash", title: "Delete account", isDestructive: true) {
                                    showDeleteAccountConfirmation = true
                                }
                            }

                            // Room so the last row doesn't hide behind the floating tab bar.
                            Color.clear.frame(height: 120)
                        }
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y
                    } action: { _, newValue in
                        scrollOffset = newValue
                    }

                    topBar
                }
                .background(Color.appHomeBackground)
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
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
        // A sheet, not another full-screen push like every other row here
        // — this is a multi-step form (see AddPodView's own `step`), and
        // a sheet reads as "a focused task on top of Profile" the way a
        // full-screen swap (meant for "another whole screen of Profile")
        // doesn't. Same presentation FriendsView already uses for
        // AddFriendSheet.
        .sheet(isPresented: $showAddPod) {
            AddPodView()
        }
    }

    // MARK: - Persistent top bar

    // 44 (avatar/back button) + 31pt padding top/bottom — matches
    // ProfileTopBar's own metrics exactly, since this bar copies its
    // visual style.
    private let topBarHeight: CGFloat = 106

    /// Same idea as PodDetailView's own persistent top bar: one fixed
    /// instance, never re-created — only a small avatar fades in (in the
    /// same slot the back button would occupy) once you've scrolled past
    /// the account row above, instead of the title sitting there blank
    /// the whole time.
    private var topBar: some View {
        HStack {
            Group {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                    }
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
                    .accessibilityLabel("Back")
                } else {
                    // 10 — same corner radius PodDetailView uses for its
                    // own small persistent top-bar photo.
                    AvatarView(imageName: auth.profile?.avatarURL, size: 32, cornerRadius: AppRadius.r10)
                        .frame(width: 44, height: 44)
                        .opacity(avatarChromeOpacity)
                }
            }

            Spacer()

            Text("Profile")
                .font(AppFont.pillLabel(24))
                .fontWeight(.heavy)
                .foregroundColor(.black)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 31)
        .frame(maxWidth: .infinity)
        .background(Color.appHomeBackground)
    }

    /// 0 at rest, 1 shortly after starting to scroll. Two earlier versions
    /// of this waited for a specific amount of scroll before completing —
    /// first a guessed pixel range (20→90, then 10→45), then the real
    /// measured height of `ProfileAccountRow` above (~104pt) — and both
    /// got reported stuck: on a profile without much content below, the
    /// screen can't actually scroll that far at rest, so that opacity only
    /// ever got reached via elastic overscroll (dragging past the natural
    /// bottom), which springs back the instant you let go — the avatar
    /// flashing in then vanishing as it settled. A small, fixed distance
    /// close to 0 sidesteps that entirely: it's reachable through completely
    /// ordinary scrolling on any device/content length (unless there's
    /// truly nothing below to scroll to at all), so it can't depend on
    /// slack that may not exist.
    private var avatarChromeOpacity: Double {
        let fadeEnd: CGFloat = 24
        return Double(min(max(scrollOffset / fadeEnd, 0), 1))
    }

    // MARK: - Stats + sections

    /// "@username · 12 friends · 4 posts · 8 likes" — one line, not a
    /// separate row — makes this screen read as a place with activity in
    /// it, not just a settings menu, now that Friends/Posts/Likes are all
    /// real features with real counts.
    private var accountSubtitle: String {
        let identity = auth.profile?.username.map { "@\($0)" } ?? "Show profile"
        return "\(identity) · \(friendsStore.friends.count) friends · \(myPostsCount) posts · \(likesStore.likes.count) likes"
    }

    private var myPostsCount: Int {
        guard let userId = auth.session?.user.id else { return 0 }
        return postsStore.posts.filter { $0.authorId == userId }.count
    }

    /// Missing any of the fields `ProfileEditView` actually lets you set
    /// (photo, age, location) — not `fullName`/`username`, which are
    /// already required at signup. `Profile` has no `bio` field to check
    /// yet.
    private var isProfileIncomplete: Bool {
        guard let profile = auth.profile else { return false }
        return profile.avatarURL == nil || profile.age == nil || profile.location == nil
    }

    private var postsActivityCount: Int {
        guard let userId = auth.session?.user.id else { return 0 }
        return postsStore.newActivityCount(onPostsAuthoredBy: userId)
    }
}

#Preview {
    ProfileView()
}

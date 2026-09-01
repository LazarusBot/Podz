//
//  FriendsView.swift
//  Podz
//
//  Created by Max Prx on 26/08/2026.
//

import SwiftUI
internal import Auth

/// Reached from Profile — incoming requests up top (Accept/Decline),
/// current friends below, and a floating button to search for someone
/// new. Same manual @State-driven push/pop pattern as ProfileView's own
/// sub-screens (ProfileEditView, LoginSecurityView), not NavigationStack —
/// this app doesn't use one anywhere.
struct FriendsView: View {
    var onBack: (() -> Void)? = nil
    @StateObject private var friendsStore = FriendsStore.shared
    @StateObject private var auth = AuthManager.shared
    @State private var showAddFriend = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ProfileTopBar(title: "Friends", onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !friendsStore.incomingRequests.isEmpty {
                            SectionLabel(title: "Requests")
                            ForEach(friendsStore.incomingRequests) { request in
                                FriendRequestRow(
                                    profile: friendsStore.profilesById[request.requesterId],
                                    onAccept: {
                                        Task { await friendsStore.respond(to: request, accept: true) }
                                    },
                                    onDecline: {
                                        Task { await friendsStore.respond(to: request, accept: false) }
                                    }
                                )
                            }
                        }

                        SectionLabel(title: friendsStore.friends.isEmpty ? "Accepted friends" : "Accepted friends (\(friendsStore.friends.count))")

                        if friendsStore.friends.isEmpty {
                            Text("No friends yet — tap + to add someone.")
                                .font(AppFont.mediumLabel(14))
                                .foregroundColor(.appTextMuted)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                        } else if let userId = auth.session?.user.id {
                            ForEach(friendsStore.friends) { friendship in
                                SwipeToDeleteRow(onDelete: {
                                    Task { await friendsStore.remove(friendship) }
                                }) {
                                    FriendRow(profile: friendsStore.profilesById[friendship.otherUserId(currentUserId: userId)])
                                }
                            }
                        }

                        // Room so the last row doesn't hide behind the
                        // floating add button or the tab bar underneath.
                        Color.clear.frame(height: 140)
                    }
                }
            }
            .background(Color.appHomeBackground)

            Button {
                showAddFriend = true
            } label: {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.black))
            }
            .padding(24)
            .accessibilityLabel("Add friend")
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
        }
        .task { await friendsStore.fetchAll() }
        // The floating "+" sits where MainTabView's own floating tab bar
        // draws on top of it, blocking taps — hide the tab bar for as
        // long as this screen is up, restore it on the way out.
        .onAppear { TabBarVisibilityState.shared.isHidden = true }
        .onDisappear { TabBarVisibilityState.shared.isHidden = false }
        // Accept/decline/remove all set `friendsStore.lastError` on
        // failure, same as every other store's write methods — nothing
        // here was ever reading it, so a failed action (RLS, network)
        // silently looked like a dead button. Same bug AddFriendSheet's
        // own `errorMessage` was added to fix for sendRequest.
        .errorAlert($friendsStore.lastError)
    }
}

private struct FriendRequestRow: View {
    let profile: Profile?
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(imageName: profile?.avatarURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.displayName ?? "Someone")
                    .font(AppFont.pillLabelBold(15))
                    .foregroundColor(.appTextPrimary)
                if let username = profile?.username {
                    Text("@\(username)")
                        .font(AppFont.mediumLabel(13))
                        .foregroundColor(.appTextMuted)
                }
            }
            Spacer()
            Button(action: onDecline) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appTextMuted)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.appIconButtonBackground))
            }
            .accessibilityLabel("Decline")
            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.appAccentBlack))
            }
            .accessibilityLabel("Accept")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

private struct FriendRow: View {
    let profile: Profile?

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(imageName: profile?.avatarURL, size: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile?.displayName ?? "Someone")
                    .font(AppFont.pillLabelBold(18))
                    .foregroundColor(.black)
                if let username = profile?.username {
                    Text("@\(username)")
                        .font(AppFont.mediumLabel(15))
                        .foregroundColor(.appTextMuted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }
}

/// Hand-rolled swipe-to-reveal-delete — not List's `.swipeActions`, since
/// this screen (like every other screen in the app) is a plain ScrollView
/// stack rather than a List, and introducing one just for this row would
/// bring its own default row chrome/insets that don't match anything else
/// here.
private struct SwipeToDeleteRow<Content: View>: View {
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isRevealed = false
    @State private var showConfirmation = false

    private let revealWidth: CGFloat = 84

    var body: some View {
        ZStack(alignment: .trailing) {
            // Full-bleed rectangle exactly matching revealWidth.
            Button {
                showConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: revealWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
            }
            .accessibilityLabel("Remove friend")

            content()
                .background(Color.appHomeBackground)
                .offset(x: offset)
        }
        // Gesture on the outer ZStack (an ancestor of the button), not on
        // content() (a sibling of it) — the previous version put the drag
        // gesture on content directly, and even though content's own
        // hit-test region followed its offset correctly, SwiftUI's touch
        // resolution between two *sibling* gesture-bearing views in a
        // ZStack isn't guaranteed to hand a tap to the one spatially under
        // the finger; an ancestor-vs-descendant relationship is what
        // reliably lets the Button's own tap recognizer win over a plain
        // .gesture() above it.
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    // Only tracks leftward drags (or dragging back
                    // right from an already-revealed state) — a
                    // rightward drag from rest does nothing, so it
                    // doesn't fight the outer ScrollView's own
                    // vertical gesture recognition.
                    let translation = value.translation.width
                    let base: CGFloat = isRevealed ? -revealWidth : 0
                    guard translation < 0 || isRevealed else { return }
                    offset = max(-revealWidth, min(0, base + translation))
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: AppMotion.snappy)) {
                        if offset < -revealWidth / 2 {
                            offset = -revealWidth
                            isRevealed = true
                        } else {
                            offset = 0
                            isRevealed = false
                        }
                    }
                }
        )
        .clipped()
        .alert("Remove this friend?", isPresented: $showConfirmation) {
            Button("Remove", role: .destructive) {
                withAnimation(.easeOut(duration: AppMotion.snappy)) {
                    offset = 0
                    isRevealed = false
                }
                onDelete()
            }
            Button("Cancel", role: .cancel) {
                withAnimation(.easeOut(duration: AppMotion.snappy)) {
                    offset = 0
                    isRevealed = false
                }
            }
        }
    }
}

#Preview {
    FriendsView()
}

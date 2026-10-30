//
//  FriendsView.swift
//  Podz
//
//  Created by Max Prx on 26/08/2026.
//

import SwiftUI
internal import Auth

/// Reached from Profile — incoming requests up top (Accept/Decline), current
/// friends below, and an "Add friend" pill in the bottom bar. Same manual
/// @State-driven push/pop pattern as ProfileView's other sub-screens, not
/// NavigationStack — this app doesn't use one anywhere.
struct FriendsView: View {
    var onBack: () -> Void
    @StateObject private var friendsStore = FriendsStore.shared
    @StateObject private var auth = AuthManager.shared
    @State private var showAddFriend = false

    var body: some View {
        SectionPage(
            title: "Friends",
            onBack: onBack,
            trailing: { DetailTextButton(title: "Add friend") { showAddFriend = true } }
        ) {
            if !friendsStore.incomingRequests.isEmpty {
                SectionHeading(title: "Requests")
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

            SectionHeading(title: friendsStore.friends.isEmpty ? "Friends" : "Friends (\(friendsStore.friends.count))")

            if friendsStore.friends.isEmpty {
                Text("No friends yet. Add someone to plan trips together.")
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.homeSubtitle)
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
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
        }
        .task { await friendsStore.fetchAll() }
        // Accept/decline/remove all set `friendsStore.lastError` on failure;
        // surface it so a failed action doesn't look like a dead button.
        .errorAlert($friendsStore.lastError)
    }
}

private struct FriendRequestRow: View {
    let profile: Profile?
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(imageName: profile?.avatarURL, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.displayName ?? "Someone")
                    .font(AppFont.semiBoldLabel(16))
                    .foregroundColor(.homeText)
                if let username = profile?.username {
                    Text("@\(username)")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                }
            }
            Spacer()
            // Decline is the quiet flat pill; Accept is the highlighted one
            // (ground and ink swapped), like "Get started".
            Button(action: onDecline) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.homeText.opacity(0.35))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.homePill.opacity(0.95)))
                    .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 1))
            }
            .buttonStyle(TapScaleButtonStyle())
            .accessibilityLabel("Decline")
            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.homeBackground)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.homeText))
            }
            .buttonStyle(TapScaleButtonStyle())
            .accessibilityLabel("Accept")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }
}

private struct FriendRow: View {
    let profile: Profile?

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(imageName: profile?.avatarURL, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile?.displayName ?? "Someone")
                    .font(AppFont.semiBoldLabel(16))
                    .foregroundColor(.homeText)
                if let username = profile?.username {
                    Text("@\(username)")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }
}

/// Hand-rolled swipe-to-reveal-delete — not List's `.swipeActions`, since
/// this screen is a plain ScrollView stack rather than a List, and
/// introducing one just for this row would bring its own default row
/// chrome/insets.
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
                    .background(Color.appBadgeRed)
            }
            .accessibilityLabel("Remove friend")

            content()
                .background(Color.homeBackground)
                .offset(x: offset)
        }
        // Gesture on the outer ZStack (an ancestor of the button), not on
        // content() (a sibling of it): an ancestor-vs-descendant
        // relationship is what reliably lets the Button's own tap
        // recognizer win over a plain .gesture() above it.
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    // Only tracks leftward drags (or dragging back right
                    // from an already-revealed state), so it doesn't fight
                    // the outer ScrollView's vertical gesture.
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
    FriendsView(onBack: {})
}

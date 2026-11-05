//
//  ShareFolderSheet.swift
//  Podz
//
//  Created by Max Prx on 26/08/2026.
//

import SwiftUI
internal import Auth

/// Per-friend toggle list granting/revoking read-only access to one like
/// folder — opened from the folder's own top bar (see ProfileTopBar's
/// trailingIcon) in LikesView.
struct ShareFolderSheet: View {
    let folder: LikeFolder
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var friendsStore = FriendsStore.shared
    @StateObject private var auth = AuthManager.shared
    @State private var pendingFriendId: UUID?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(style: .pill, size: 44, action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            VStack(spacing: 4) {
                T("Share \"\(folder.name)\"")
                    .font(AppFont.semiBoldLabel(20))
                    .foregroundColor(.homeText)
                T("Friends you share it with can view this folder, read-only.")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)

            if friendsStore.friends.isEmpty {
                // The empty-page recipe; no caption, the friends are in Profile.
                LennyEmptyState(
                    title: "No friends yet",
                    line: "Add friends in Profile, then share this folder with them."
                )
                Spacer()
            } else if let userId = auth.session?.user.id {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(friendsStore.friends) { friendship in
                            let friendId = friendship.otherUserId(currentUserId: userId)
                            friendRow(friendId: friendId)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .background(Color.homeBackground)
        .task { await friendsStore.fetchAll() }
        .lennyNote($errorMessage, prefix: "I couldn't update the sharing.", abovePills: false, respectsSafeArea: true)
    }

    private func friendRow(friendId: UUID) -> some View {
        let profile = friendsStore.profilesById[friendId]
        let hasAccess = likesStore.friendIdsWithAccess(to: folder.id).contains(friendId)

        return HStack(spacing: 12) {
            AvatarView(imageName: profile?.avatarURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.displayName ?? "Someone")
                    .font(AppFont.semiBoldLabel(15))
                    .foregroundColor(.homeText)
                if let username = profile?.username {
                    T("@\(username)")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                }
            }
            Spacer()

            sharePill(hasAccess: hasAccess, isPending: pendingFriendId == friendId) {
                toggleAccess(for: friendId, grant: !hasAccess)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    /// The small action pill, not a system switch: flat `homePill` "Share" while
    /// the folder isn't shared with them, the highlighted one (ground and ink
    /// swapped) "Shared" once it is; Lenny's dots while it's being changed.
    /// One button that never swaps for another view, so a tap can't be lost.
    private func sharePill(hasAccess: Bool, isPending: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isPending {
                    LennyDots(color: hasAccess ? .homeBackground : .homeText, size: 6)
                } else {
                    T(hasAccess ? "Shared" : "Share")
                        .font(AppFont.semiBoldLabel(14))
                }
            }
            .foregroundColor(hasAccess ? .homeBackground : .homeText)
            .frame(width: 84, height: 38)
            .background(Capsule().fill(hasAccess ? Color.homeText : Color.homePill))
        }
        .buttonStyle(TapScaleButtonStyle())
        .disabled(isPending)
        .animation(.smooth(duration: 0.25), value: hasAccess)
        .accessibilityLabel(tr(hasAccess ? "Stop sharing" : "Share"))
    }

    private func toggleAccess(for friendId: UUID, grant: Bool) {
        pendingFriendId = friendId
        Task {
            if grant {
                await likesStore.shareFolder(folder.id, with: friendId)
            } else {
                await likesStore.unshareFolder(folder.id, with: friendId)
            }
            if let error = likesStore.lastError {
                errorMessage = error
                likesStore.lastError = nil
            }
            pendingFriendId = nil
        }
    }
}

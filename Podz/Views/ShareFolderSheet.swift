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
                CloseButton(action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            VStack(spacing: 4) {
                Text("Share \"\(folder.name)\"")
                    .font(AppFont.pillLabel(20))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Text("Friends you turn on can view this folder, read-only.")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.appTextMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)

            if friendsStore.friends.isEmpty {
                Text("Add some friends first — nobody to share with yet.")
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.appTextMuted)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
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
        .background(Color.appHomeBackground)
        .task { await friendsStore.fetchAll() }
        .alert("Couldn't update sharing", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func friendRow(friendId: UUID) -> some View {
        let profile = friendsStore.profilesById[friendId]
        let hasAccess = likesStore.friendIdsWithAccess(to: folder.id).contains(friendId)

        return HStack(spacing: 12) {
            AvatarView(imageName: profile?.avatarURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.displayName ?? "Someone")
                    .font(AppFont.pillLabelBold(15))
                    .foregroundColor(.black)
                if let username = profile?.username {
                    Text("@\(username)")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.appTextMuted)
                }
            }
            Spacer()

            if pendingFriendId == friendId {
                ProgressView()
                    .frame(width: 51, height: 31)
            } else {
                Toggle("", isOn: Binding(
                    get: { hasAccess },
                    set: { newValue in toggleAccess(for: friendId, grant: newValue) }
                ))
                .labelsHidden()
                .tint(.black)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
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

//
//  MyPostDetailView.swift
//  Podz
//
//  Created by Max Prx on 28/08/2026.
//

import SwiftUI

/// Expanded look at one of your own posts, reached by tapping a cell in
/// MyPostsView's grid — every photo at a real size (not the grid's small
/// square crop), the caption, and a delete action in the top bar. Same
/// manual @State-driven push/pop pattern as the rest of this screen's
/// ancestry, not NavigationStack.
struct MyPostDetailView: View {
    let post: Post
    var onBack: () -> Void

    @StateObject private var postsStore = PostsStore.shared
    @StateObject private var podsStore = PodsStore.shared
    @State private var showDeleteConfirmation = false

    private var pod: Pod? { podsStore.pods.first { $0.id == post.podId } }
    private var photos: [PostPhoto] { postsStore.photos(for: post.id) }
    private var comments: [PostComment] { postsStore.comments(for: post.id) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileTopBar(
                    title: pod?.name ?? "Post",
                    onBack: onBack,
                    trailingIcon: "trash",
                    onTrailingTap: { showDeleteConfirmation = true },
                    trailingAccessibilityLabel: "Delete post"
                )

                VStack(alignment: .leading, spacing: 16) {
                    if !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photos) { photo in
                                    PodPhoto(url: photo.url)
                                        .frame(width: 280, height: 280)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    if let body = post.body, !body.isEmpty {
                        Text(body)
                            .font(AppFont.mediumLabel(15))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                    }

                    HStack(spacing: 16) {
                        Label("\(postsStore.likeCount(for: post.id))", systemImage: "heart.fill")
                            .foregroundColor(.red)
                        Label("\(comments.count)", systemImage: "bubble.left.fill")
                            .foregroundColor(.appMessageBlue)
                        Spacer()
                        Text(Self.relativeTime(post.createdAt))
                            .foregroundColor(.appTextMuted)
                    }
                    .font(AppFont.mediumLabel(13))
                    .padding(.horizontal, 24)

                    if !comments.isEmpty {
                        Divider().padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(comments) { comment in
                                HStack(alignment: .top, spacing: 8) {
                                    AvatarView(imageName: postsStore.profile(for: comment.authorId)?.avatarURL, size: 24)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(postsStore.profile(for: comment.authorId)?.displayName ?? "Someone")
                                            .font(AppFont.pillLabelBold(13))
                                            .foregroundColor(.black)
                                        Text(comment.body)
                                            .font(AppFont.mediumLabel(13))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 16)
            }
        }
        .background(Color.appHomeBackground)
        .task { await postsStore.fetchCommentsIfNeeded(for: post.id) }
        .alert("Delete this post?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await postsStore.deletePost(post)
                    onBack()
                }
            }
        } message: {
            Text("This removes it from your feed and your friends', along with its likes and comments.")
        }
    }

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

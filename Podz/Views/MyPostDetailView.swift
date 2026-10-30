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
        SectionPage(
            title: pod?.name ?? "Post",
            onBack: onBack,
            trailing: { deleteButton }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                if !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(photos) { photo in
                                PodPhoto(url: photo.url)
                                    .frame(width: 240, height: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                if let body = post.body, !body.isEmpty {
                    Text(body)
                        .font(AppFont.regularLabel(16))
                        .lineSpacing(5)
                        .foregroundColor(.homeText)
                        .padding(.horizontal, 24)
                }

                Text("\(postsStore.likeCount(for: post.id)) likes · \(comments.count) comments · \(Self.relativeTime(post.createdAt))")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .padding(.horizontal, 24)

                if !comments.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: 10) {
                                AvatarView(imageName: postsStore.profile(for: comment.authorId)?.avatarURL, size: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(postsStore.profile(for: comment.authorId)?.displayName ?? "Someone")
                                        .font(AppFont.semiBoldLabel(13))
                                        .foregroundColor(.homeText)
                                    Text(comment.body)
                                        .font(AppFont.regularLabel(14))
                                        .foregroundColor(.homeText)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) { Hairline() }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
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

    /// A flat pill with the label in the error color.
    private var deleteButton: some View {
        Button { showDeleteConfirmation = true } label: {
            Text("Delete")
                .font(AppFont.regularLabel(14))
                .foregroundColor(.appBadgeRed)
                .frame(maxWidth: .infinity)
                .frame(height: 83)
                .background(DetailPill())
        }
        .buttonStyle(TapScaleButtonStyle())
    }

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

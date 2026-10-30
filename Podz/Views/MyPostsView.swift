//
//  MyPostsView.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import SwiftUI
internal import Auth

/// Reached from Profile — every post you've authored, as a photo grid
/// (tap a cell to expand it — see MyPostDetailView, which is also where
/// deleting lives), plus a bell in the header for likes/comments other
/// people left on your posts (PostsActivityView). Same manual
/// @State-driven push/pop pattern as ProfileView's other sub-screens.
struct MyPostsView: View {
    var onBack: () -> Void

    @StateObject private var postsStore = PostsStore.shared
    @StateObject private var auth = AuthManager.shared
    @State private var selectedPost: Post?
    @State private var showActivity = false

    private var myPosts: [Post] {
        guard let userId = auth.session?.user.id else { return [] }
        return postsStore.posts.filter { $0.authorId == userId }
    }

    /// Same source PostsActivityView itself reads, reduced to a plain
    /// presence check — same reasoning as BottomTabBar's own
    /// `hasNewPostActivity` dot on the Profile tab avatar.
    private var hasNewActivity: Bool {
        guard let userId = auth.session?.user.id else { return false }
        return postsStore.newActivityCount(onPostsAuthoredBy: userId) > 0
    }

    private let columnCount = 3
    private let cellSpacing: CGFloat = 8
    private let horizontalMargin: CGFloat = 24

    /// One explicit number every cell is given, so they're all the same
    /// square regardless of each photo's real dimensions.
    private var cellSize: CGFloat {
        (UIScreen.main.bounds.width - horizontalMargin * 2 - cellSpacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: columnCount)
    }

    var body: some View {
        Group {
            if let post = selectedPost {
                MyPostDetailView(post: post, onBack: { selectedPost = nil })
            } else {
                SectionPage(
                    title: "Posts",
                    onBack: onBack,
                    trailing: { activityButton }
                ) {
                    if myPosts.isEmpty {
                        Text("You haven't posted anything yet.")
                            .font(AppFont.regularLabel(14))
                            .foregroundColor(.homeSubtitle)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    } else {
                        LazyVGrid(columns: columns, spacing: cellSpacing) {
                            ForEach(myPosts) { post in
                                Button(action: { selectedPost = post }) {
                                    GridCell(
                                        size: cellSize,
                                        photoURL: postsStore.photos(for: post.id).first?.url,
                                        photoCount: postsStore.photos(for: post.id).count
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, horizontalMargin)
                    }
                }
                .task { await postsStore.fetchFeed() }
                .sheet(isPresented: $showActivity) {
                    PostsActivityView()
                        // No search field, and its own doc comment already
                        // frames this as "a lightweight, dismiss-anytime
                        // overlay" — doesn't need the full sheet.
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.hidden)
                }
            }
        }
    }

    /// The bell, as a text pill; a small dot while something is new.
    private var activityButton: some View {
        DetailTextButton(title: "Activity") { showActivity = true }
            .overlay(alignment: .topTrailing) {
                if hasNewActivity {
                    Circle()
                        .fill(Color.homeText)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 2))
                        .offset(x: -18, y: 14)
                }
            }
    }
}

/// One square grid cell — a hard, exact `size × size` frame, the same
/// for every cell regardless of its photo's own real dimensions.
private struct GridCell: View {
    let size: CGFloat
    let photoURL: String?
    let photoCount: Int

    var body: some View {
        PodPhoto(url: photoURL, contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if photoCount > 1 {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .padding(6)
                }
            }
    }
}

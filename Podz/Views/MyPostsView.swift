//
//  MyPostsView.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import SwiftUI
internal import Auth

/// Reports the grid's real available width — same background-
/// GeometryReader-plus-preference trick as PodCard's own
/// `SectionWidthPreferenceKey`.
private struct MyPostsGridWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = UIScreen.main.bounds.width
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Reached from Profile — every post you've authored, as a photo grid
/// (tap a cell to expand it — see MyPostDetailView, which is also where
/// deleting lives), plus a bell in the header for likes/comments other
/// people left on your posts (PostsActivityView). Same manual
/// @State-driven push/pop pattern as ProfileView's other sub-screens.
struct MyPostsView: View {
    var onBack: (() -> Void)? = nil

    @StateObject private var postsStore = PostsStore.shared
    @StateObject private var auth = AuthManager.shared
    @State private var selectedPost: Post?
    @State private var showActivity = false
    @State private var gridWidth: CGFloat = UIScreen.main.bounds.width

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
    private let cellSpacing: CGFloat = 2

    /// One explicit number every cell is given via `.frame(width:
    /// height:)` — not `.aspectRatio`, which (per PostCard's own history
    /// this session) doesn't reliably pin every cell to the *same* size
    /// on its own. A measured, hard-fixed size is simpler to reason about
    /// and guaranteed uniform regardless of each photo's real dimensions.
    private var cellSize: CGFloat {
        (gridWidth - cellSpacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: columnCount)
    }

    var body: some View {
        Group {
            if let post = selectedPost {
                MyPostDetailView(post: post, onBack: { selectedPost = nil })
            } else {
                VStack(spacing: 0) {
                    ProfileTopBar(
                        title: "Posts",
                        onBack: onBack,
                        trailingIcon: "bell",
                        onTrailingTap: { showActivity = true },
                        trailingAccessibilityLabel: "Activity",
                        trailingBadge: hasNewActivity
                    )

                    if myPosts.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
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
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: MyPostsGridWidthPreferenceKey.self, value: geo.size.width)
                            }
                        )
                        .onPreferenceChange(MyPostsGridWidthPreferenceKey.self) { gridWidth = $0 }
                    }
                }
                // The empty state has no ScrollView/Spacer to greedily
                // fill the screen the way the populated grid's ScrollView
                // does — without this, MainTabView's outer ZStack sized
                // itself to this shorter content instead of the full
                // screen, which dragged the floating tab bar (bottom-
                // aligned within that now-shrunk ZStack) up to sit right
                // under it instead of at the true bottom edge. `.top`,
                // not the default center — otherwise the short content
                // (header included) centers within the now-full-height
                // frame instead of staying pinned to the top.
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Color.appHomeBackground)
                .task { await postsStore.fetchFeed() }
                .sheet(isPresented: $showActivity) {
                    PostsActivityView()
                        // No search field, and its own doc comment already
                        // frames this as "a lightweight, dismiss-anytime
                        // overlay" — doesn't need the full sheet.
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("You haven't posted anything yet.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
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
            .clipped()
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

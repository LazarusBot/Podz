//
//  PostDetailView.swift
//  Podz
//
//  Created by Max Prx on 31/08/2026.
//

import SwiftUI

/// One friend's post, full screen — reached by tapping anywhere on its
/// `PostCard` in HomeView's friends feed. Same `PostCard`, pushed instead
/// of inline, but with its own comment thread capped to 1
/// (`maxVisibleComments`) rather than showing the whole thing — this
/// screen's own comment count already says there's more, and a long
/// inline thread just pushed everything else (the "Add a comment" row
/// included) arbitrarily far down the scroll.
struct PostDetailView: View {
    let post: Post
    var onBack: () -> Void
    var onTapPod: (() -> Void)? = nil

    /// Same persistent-top-bar pattern as LikesView's own folder screen
    /// and PodDetailView — one fixed `ProfileTopBar` overlaying the
    /// scroll content instead of scrolling away with it, with a matching
    /// `Color.clear` spacer reserving its space at the top of that
    /// content. 106 = ProfileTopBar's own real height (44pt back button +
    /// 31pt padding top/bottom).
    private let topBarHeight: CGFloat = 106
    /// Extra room below the card, past its own bottom padding — the
    /// keyboard covers roughly this much of the screen on most iPhones,
    /// and a `ScrollView` can only scroll a focused field above the
    /// keyboard if there's actually enough real content height below it
    /// to scroll *into*. Without this, the "Add a comment" row (already
    /// near the bottom, now that comments are capped to 1) had nowhere
    /// to go and stayed covered.
    private let keyboardScrollSlack: CGFloat = 300

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: topBarHeight)

                    PostCard(
                        post: post,
                        cardWidth: cardWidth,
                        onTapPod: onTapPod,
                        showComments: true,
                        maxVisibleComments: 1
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, keyboardScrollSlack)
                }
            }
            .background(Color.appHomeBackground)

            ProfileTopBar(title: "Post", onBack: onBack)
        }
        .background(Color.appHomeBackground)
        // A focused text field's own keyboard already covers the global
        // tab bar's usual spot — leaving the bar mounted underneath it
        // just means it's floating unreachable behind the keyboard. Same
        // pattern as ConversationView/FriendsView.
        .onAppear { TabBarVisibilityState.shared.isHidden = true }
        .onDisappear { TabBarVisibilityState.shared.isHidden = false }
    }

    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - 48
    }
}

#Preview {
    PostDetailView(post: Post(id: UUID(), authorId: UUID(), podId: UUID(), body: "Preview", createdAt: Date()), onBack: {})
}

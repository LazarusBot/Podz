//
//  PostDetailView.swift
//  Podz
//
//  Created by Max Prx on 31/08/2026.
//

import SwiftUI

/// One friend's post, full screen — reached by tapping anywhere on its
/// `PostCard` in HomeView's friends feed. Just that same `PostCard`,
/// pushed instead of inline, with `showComments` on so the full thread
/// and the "Add a comment" field are always visible (no elevated overlay,
/// no inline expand — this screen *is* the expanded view).
struct PostDetailView: View {
    let post: Post
    var onBack: () -> Void
    var onTapPod: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileTopBar(title: "Post", onBack: onBack)

                PostCard(post: post, cardWidth: cardWidth, onTapPod: onTapPod, showComments: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
        .background(Color.appHomeBackground)
    }

    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width - 48
    }
}

#Preview {
    PostDetailView(post: Post(id: UUID(), authorId: UUID(), podId: UUID(), body: "Preview", createdAt: Date()), onBack: {})
}

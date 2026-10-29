//
//  PostsActivityView.swift
//  Podz
//
//  Created by Max Prx on 28/08/2026.
//

import SwiftUI
internal import Auth

/// "Who liked/commented on my posts" — reached from MyPostsView's bell
/// icon. A sheet, not a pushed screen (MyPostsView's own header stays
/// visible underneath, matching ShareFolderSheet's pattern for a
/// lightweight, dismiss-anytime overlay rather than another full stop in
/// the push/pop chain).
struct PostsActivityView: View {
    @StateObject private var postsStore = PostsStore.shared
    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var auth = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    /// `activitySeenAt` as of *before* this screen marks everything seen —
    /// captured once on appear, before that call moves it to now. Rows
    /// compare against this frozen snapshot (not the live, now-updated
    /// `postsStore.activitySeenAt`) to tell which items were already seen
    /// on a previous visit and grey those out, vs. ones that are new this
    /// time and still get full-strength treatment for this one viewing.
    @State private var seenBeforeThisVisit: Date?

    private var activity: [PostActivity] {
        guard let userId = auth.session?.user.id else { return [] }
        return postsStore.activity(onPostsAuthoredBy: userId)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(style: .pill, size: 44, action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text("Activity")
                .font(AppFont.semiBoldLabel(20))
                .foregroundColor(.homeText)
                .padding(.top, 8)
                .padding(.bottom, 12)

            if activity.isEmpty {
                Spacer()
VStack(spacing: 12) {
                    Text("No likes or comments on your posts yet.")
                        .font(AppFont.regularLabel(14))
                        .foregroundColor(.homeSubtitle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(activity) { item in
                            ActivityRow(
                                item: item,
                                actorProfile: postsStore.profile(for: item.actorId),
                                podName: podsStore.pods.first(where: { $0.id == postForPostId(item.postId)?.podId })?.name,
                                isSeen: (seenBeforeThisVisit ?? .distantPast) >= item.createdAt
                            )
                        }
                    }
                }
            }
        }
        .background(Color.homeBackground)
        // Opening this screen is what "seeing" the activity means — the
        // tab-bar dot and the Posts row's pill both key off
        // `activitySeenAt`, so this is what actually clears them. Snapshot
        // the old value first — `markActivitySeen()` immediately moves
        // `activitySeenAt` to now, and rows need the *previous* threshold
        // to know what was already seen before this visit.
        .onAppear {
            seenBeforeThisVisit = postsStore.activitySeenAt
            postsStore.markActivitySeen()
        }
    }

    private func postForPostId(_ postId: UUID) -> Post? {
        postsStore.posts.first { $0.id == postId }
    }
}

private struct ActivityRow: View {
    let item: PostActivity
    let actorProfile: Profile?
    let podName: String?
    /// Already seen on a previous visit to this screen — recolored flat
    /// subtitle-gray, so a seen row is unmistakably quieter than a new one.
    var isSeen: Bool = false

    private var actionText: String {
        switch item.kind {
        case .like: "liked your post"
        case .comment: "commented on your post"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(imageName: actorProfile?.avatarURL, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                (
                    Text(actorProfile?.displayName ?? "Someone").fontWeight(.semibold)
                        + Text(" \(actionText)")
                )
                .font(AppFont.regularLabel(14))
                .foregroundColor(isSeen ? .homeSubtitle : .homeText)

                if case .comment(let body) = item.kind {
                    Text("\u{201C}\(body)\u{201D}")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    if let podName {
                        Text(podName)
                        Text("·")
                    }
                    Text(Self.relativeTime(item.createdAt))
                }
                .font(AppFont.regularLabel(12))
                .foregroundColor(.homeSubtitle)
            }

            Spacer()

            Image(systemName: item.isLike ? "heart.fill" : "bubble.left.fill")
                .font(.system(size: 13))
                .foregroundColor(isSeen ? .homeSubtitle : .homeText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private extension PostActivity {
    var isLike: Bool {
        if case .like = kind { return true }
        return false
    }
}

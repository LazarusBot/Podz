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

    private var activity: [PostActivity] {
        guard let userId = auth.session?.user.id else { return [] }
        return postsStore.activity(onPostsAuthoredBy: userId)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextMuted)
                        .frame(width: 31, height: 31)
                        .background(Circle().fill(Color(white: 0.93)))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text("Activity")
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 8)
                .padding(.bottom, 12)

            if activity.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bell")
                        .font(.system(size: 32))
                        .foregroundColor(.appTextMuted)
                    Text("No likes or comments on your posts yet.")
                        .font(AppFont.mediumLabel(14))
                        .foregroundColor(.appTextMuted)
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
                                podName: podsStore.pods.first(where: { $0.id == postForPostId(item.postId)?.podId })?.name
                            )
                        }
                    }
                }
            }
        }
        .background(Color.appHomeBackground)
        // Opening this screen is what "seeing" the activity means — the
        // tab-bar dot and the Posts row's pill both key off
        // `activitySeenAt`, so this is what actually clears them.
        .onAppear { postsStore.markActivitySeen() }
    }

    private func postForPostId(_ postId: UUID) -> Post? {
        postsStore.posts.first { $0.id == postId }
    }
}

private struct ActivityRow: View {
    let item: PostActivity
    let actorProfile: Profile?
    let podName: String?

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
                .font(AppFont.mediumLabel(14))
                .foregroundColor(.black)

                if case .comment(let body) = item.kind {
                    Text("\u{201C}\(body)\u{201D}")
                        .font(AppFont.mediumLabel(13))
                        .foregroundColor(.appTextMuted)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    if let podName {
                        Text(podName)
                        Text("·")
                    }
                    Text(Self.relativeTime(item.createdAt))
                }
                .font(AppFont.mediumLabel(11))
                .foregroundColor(.appTextMuted)
            }

            Spacer()

            Image(systemName: item.isLike ? "heart.fill" : "bubble.left.fill")
                .font(.system(size: 13))
                .foregroundColor(item.isLike ? .red : .appMessageBlue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
        }
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

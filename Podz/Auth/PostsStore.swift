//
//  PostsStore.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import Foundation
import Combine
import SwiftUI
import UIKit
internal import Auth
import Supabase
import Storage

@MainActor
final class PostsStore: ObservableObject {
    static let shared = PostsStore()

    @Published private(set) var posts: [Post] = []
    @Published private(set) var photosByPostId: [UUID: [PostPhoto]] = [:]
    @Published private(set) var likes: [PostLike] = []
    @Published private(set) var commentsByPostId: [UUID: [PostComment]] = [:]
    /// Author/commenter profiles this store had to fetch itself — a
    /// commenter isn't guaranteed to already be in
    /// `FriendsStore.shared.profilesById` (e.g. a friend of the post's
    /// author who isn't a friend of yours). Checked as a fallback after
    /// FriendsStore's own cache and `AuthManager.shared.profile`.
    @Published private(set) var profilesById: [UUID: Profile] = [:]
    @Published var lastError: String?
    /// When you last opened PostsActivityView — persisted locally (same
    /// UserDefaults-backed "seen it" pattern as HomeView's own
    /// `hasSeenLennyCoachmark`), not a server column. There's no
    /// per-item read receipt for likes/comments; this is what lets the
    /// tab-bar dot and the Posts row's pill actually clear once you've
    /// looked, instead of staying on forever the moment a single like
    /// ever lands.
    @Published private(set) var activitySeenAt: Date

    private static let activitySeenAtDefaultsKey = "podz.postsActivitySeenAt"

    private init() {
        let stored = UserDefaults.standard.double(forKey: Self.activitySeenAtDefaultsKey)
        activitySeenAt = stored > 0 ? Date(timeIntervalSince1970: stored) : .distantPast
    }

    /// Call when PostsActivityView appears — everything up to this
    /// instant counts as seen from here on.
    func markActivitySeen() {
        activitySeenAt = Date()
        UserDefaults.standard.set(activitySeenAt.timeIntervalSince1970, forKey: Self.activitySeenAtDefaultsKey)
    }

    func photos(for postId: UUID) -> [PostPhoto] {
        photosByPostId[postId] ?? []
    }

    func comments(for postId: UUID) -> [PostComment] {
        commentsByPostId[postId] ?? []
    }

    func likeCount(for postId: UUID) -> Int {
        likes.filter { $0.postId == postId }.count
    }

    func isLiked(_ post: Post) -> Bool {
        guard let userId = AuthManager.shared.session?.user.id else { return false }
        return likes.contains { $0.postId == post.id && $0.userId == userId }
    }

    func profile(for userId: UUID) -> Profile? {
        if userId == AuthManager.shared.profile?.id { return AuthManager.shared.profile }
        return FriendsStore.shared.profilesById[userId] ?? profilesById[userId]
    }

    /// Likes and comments from *other people* on posts you authored,
    /// newest first — built from the same `likes`/`commentsByPostId`
    /// `fetchFeed()` already loaded, not a separate query. RLS only lets
    /// someone like/comment on a post they can see (its author, or an
    /// accepted friend of the author), so every actor here is guaranteed
    /// to already be in `FriendsStore.shared.profilesById` (likes) or
    /// `profilesById` (comments, fetched alongside them in `fetchFeed`).
    func activity(onPostsAuthoredBy userId: UUID) -> [PostActivity] {
        let myPostIds = Set(posts.filter { $0.authorId == userId }.map(\.id))
        guard !myPostIds.isEmpty else { return [] }

        let likeActivity = likes
            .filter { myPostIds.contains($0.postId) && $0.userId != userId }
            .map {
                PostActivity(
                    id: "like-\($0.postId)-\($0.userId)",
                    postId: $0.postId,
                    actorId: $0.userId,
                    createdAt: $0.createdAt,
                    kind: .like
                )
            }

        let commentActivity = commentsByPostId
            .filter { myPostIds.contains($0.key) }
            .flatMap(\.value)
            .filter { $0.authorId != userId }
            .map {
                PostActivity(
                    id: "comment-\($0.id)",
                    postId: $0.postId,
                    actorId: $0.authorId,
                    createdAt: $0.createdAt,
                    kind: .comment(body: $0.body)
                )
            }

        return (likeActivity + commentActivity).sorted { $0.createdAt > $1.createdAt }
    }

    /// Same list as `activity(onPostsAuthoredBy:)`, just narrowed to
    /// what's newer than `activitySeenAt` — what the tab-bar dot and the
    /// Posts row's pill should actually count, so they clear once you've
    /// opened PostsActivityView instead of staying on forever.
    func newActivityCount(onPostsAuthoredBy userId: UUID) -> Int {
        activity(onPostsAuthoredBy: userId).filter { $0.createdAt > activitySeenAt }.count
    }

    /// Friends' posts + your own, newest first. Refreshes FriendsStore
    /// first so the friend-id filter is never stale, without HomeView
    /// needing to know about that dependency.
    func fetchFeed() async {
        await FriendsStore.shared.fetchAll()
        guard let userId = AuthManager.shared.session?.user.id else { return }
        let authorIds = Set(FriendsStore.shared.friends.map { $0.otherUserId(currentUserId: userId) }).union([userId])

        do {
            let fetchedPosts: [Post] = try await supabase
                .from("posts")
                .select()
                .in("author_id", values: authorIds.map { $0.uuidString })
                .order("created_at", ascending: false)
                .execute()
                .value
            posts = fetchedPosts

            let postIds = fetchedPosts.map { $0.id }
            guard !postIds.isEmpty else {
                photosByPostId = [:]
                likes = []
                commentsByPostId = [:]
                return
            }

            async let photosTask: [PostPhoto] = supabase
                .from("post_photos")
                .select()
                .in("post_id", values: postIds.map { $0.uuidString })
                .order("position")
                .execute()
                .value
            async let likesTask: [PostLike] = supabase
                .from("post_likes")
                .select()
                .in("post_id", values: postIds.map { $0.uuidString })
                .execute()
                .value
            // Fetched eagerly, not lazily on expand — PostCard shows its
            // comment thread by default whenever there's at least one, so
            // it needs the count up front rather than after a first tap.
            async let commentsTask: [PostComment] = supabase
                .from("post_comments")
                .select()
                .in("post_id", values: postIds.map { $0.uuidString })
                .order("created_at")
                .execute()
                .value
            let (fetchedPhotos, fetchedLikes, fetchedComments) = try await (photosTask, likesTask, commentsTask)

            photosByPostId = Dictionary(grouping: fetchedPhotos, by: \.postId)
            likes = fetchedLikes
            // Seed every post with at least an empty array, not just the
            // ones `Dictionary(grouping:)` found comments for — otherwise
            // a comment-free post reads as "not fetched yet" and
            // `fetchCommentsIfNeeded` re-queries it the first time its
            // thread is manually expanded.
            var grouped = Dictionary(grouping: fetchedComments, by: \.postId)
            for postId in postIds where grouped[postId] == nil {
                grouped[postId] = []
            }
            commentsByPostId = grouped
            await fetchProfilesIfNeeded(for: Set(fetchedComments.map { $0.authorId }))
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Inserts the post row, uploads each photo to Storage, then inserts
    /// the resulting `post_photos` rows — same JPEG-compression + per-user
    /// path pattern as AvatarPicker.upload. Returns whether it succeeded.
    func createPost(pod: Pod, body: String, images: [UIImage]) async -> Bool {
        guard let userId = AuthManager.shared.session?.user.id else { return false }
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let inserted: Post = try await supabase
                .from("posts")
                .insert(PostInsert(authorId: userId, podId: pod.id, body: trimmedBody.isEmpty ? nil : trimmedBody))
                .select()
                .single()
                .execute()
                .value

            var uploadedPhotos: [PostPhoto] = []
            for (index, image) in images.enumerated() {
                guard let jpegData = image.jpegData(compressionQuality: 0.8) else { continue }
                let path = "\(userId.uuidString.lowercased())/\(inserted.id.uuidString.lowercased())/\(index).jpg"

                try await supabase.storage
                    .from("post-photos")
                    .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
                let publicURL = try supabase.storage.from("post-photos").getPublicURL(path: path)

                let photo: PostPhoto = try await supabase
                    .from("post_photos")
                    .insert(PostPhotoInsert(postId: inserted.id, url: publicURL.absoluteString, position: index))
                    .select()
                    .single()
                    .execute()
                    .value
                uploadedPhotos.append(photo)
            }

            posts.insert(inserted, at: 0)
            photosByPostId[inserted.id] = uploadedPhotos
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Deletes one of *your own* posts (optimistic) — `post_photos`,
    /// `post_likes`, and `post_comments` rows cascade-delete with it
    /// server-side. The actual Storage files don't cascade, so they're
    /// removed separately afterward, best-effort — the DB delete is what
    /// actually makes the post gone from everyone's feed, so a Storage
    /// cleanup failure just leaves orphaned files rather than a stuck or
    /// incorrectly-restored post.
    func deletePost(_ post: Post) async {
        guard let userId = AuthManager.shared.session?.user.id, post.authorId == userId else { return }
        let previousPosts = posts
        let previousPhotos = photosByPostId[post.id]
        let previousLikes = likes
        let previousComments = commentsByPostId[post.id]
        let photosToRemove = photosByPostId[post.id] ?? []

        posts.removeAll { $0.id == post.id }
        photosByPostId.removeValue(forKey: post.id)
        likes.removeAll { $0.postId == post.id }
        commentsByPostId.removeValue(forKey: post.id)

        do {
            try await supabase
                .from("posts")
                .delete()
                .eq("id", value: post.id)
                .eq("author_id", value: userId)
                .execute()

            if !photosToRemove.isEmpty {
                // Reconstructed from the same path convention
                // `createPost` uploads to, not parsed back out of the
                // stored public URL.
                let paths = photosToRemove.map {
                    "\(userId.uuidString.lowercased())/\(post.id.uuidString.lowercased())/\($0.position).jpg"
                }
                try? await supabase.storage.from("post-photos").remove(paths: paths)
            }
        } catch {
            posts = previousPosts
            if let previousPhotos { photosByPostId[post.id] = previousPhotos }
            likes = previousLikes
            if let previousComments { commentsByPostId[post.id] = previousComments }
            lastError = error.localizedDescription
        }
    }

    func toggleLike(_ post: Post) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        let alreadyLiked = isLiked(post)

        withAnimation {
            if alreadyLiked {
                likes.removeAll { $0.postId == post.id && $0.userId == userId }
            } else {
                likes.append(PostLike(postId: post.id, userId: userId))
            }
        }

        do {
            if alreadyLiked {
                try await supabase
                    .from("post_likes")
                    .delete()
                    .eq("post_id", value: post.id)
                    .eq("user_id", value: userId)
                    .execute()
            } else {
                try await supabase
                    .from("post_likes")
                    .insert(PostLike(postId: post.id, userId: userId))
                    .execute()
            }
        } catch {
            withAnimation {
                if alreadyLiked {
                    likes.append(PostLike(postId: post.id, userId: userId))
                } else {
                    likes.removeAll { $0.postId == post.id && $0.userId == userId }
                }
            }
            lastError = error.localizedDescription
        }
    }

    /// Fetches a post's comments if not already cached — safe to call
    /// every time a card's comment section expands.
    func fetchCommentsIfNeeded(for postId: UUID) async {
        guard commentsByPostId[postId] == nil else { return }
        do {
            let fetched: [PostComment] = try await supabase
                .from("post_comments")
                .select()
                .eq("post_id", value: postId)
                .order("created_at")
                .execute()
                .value
            commentsByPostId[postId] = fetched
            await fetchProfilesIfNeeded(for: Set(fetched.map { $0.authorId }))
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fetchProfilesIfNeeded(for userIds: Set<UUID>) async {
        let missing = userIds.filter { profile(for: $0) == nil }
        guard !missing.isEmpty else { return }
        do {
            let fetched: [Profile] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: Array(missing).map { $0.uuidString })
                .execute()
                .value
            for profile in fetched {
                profilesById[profile.id] = profile
            }
        } catch {
            // Non-fatal — the relevant row just shows a fallback name.
        }
    }

    func addComment(to post: Post, body: String) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let optimisticId = UUID()
        let optimistic = PostComment(id: optimisticId, postId: post.id, authorId: userId, body: trimmed, createdAt: Date())
        commentsByPostId[post.id, default: []].append(optimistic)

        do {
            let inserted: PostComment = try await supabase
                .from("post_comments")
                .insert(PostCommentInsert(postId: post.id, authorId: userId, body: trimmed))
                .select()
                .single()
                .execute()
                .value
            if let index = commentsByPostId[post.id]?.firstIndex(where: { $0.id == optimisticId }) {
                commentsByPostId[post.id]?[index] = inserted
            }
        } catch {
            commentsByPostId[post.id]?.removeAll { $0.id == optimisticId }
            lastError = error.localizedDescription
        }
    }
}

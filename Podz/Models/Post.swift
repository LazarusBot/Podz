//
//  Post.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import Foundation

/// Mirrors a row in the `posts` table (see SQL/posts_feed.sql) — a friend
/// posting about a pod, with optional text. Photos live in their own table
/// (`PostPhoto`), same split as Pod/PodPhotoRow.
struct Post: Codable, Identifiable, Equatable {
    let id: UUID
    let authorId: UUID
    let podId: UUID
    var body: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case podId = "pod_id"
        case body
        case createdAt = "created_at"
    }
}

struct PostPhoto: Codable, Identifiable, Equatable {
    let id: UUID
    let postId: UUID
    let url: String
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case url
        case position
    }
}

struct PostLike: Codable, Equatable {
    let postId: UUID
    let userId: UUID
    /// Defaults to "now" so constructing one for an optimistic insert
    /// (see `PostsStore.toggleLike`) doesn't need a value supplied at the
    /// call site — the real row's `created_at` (server default) overrides
    /// this once `fetchFeed()` re-reads it.
    var createdAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct PostComment: Codable, Identifiable, Equatable {
    let id: UUID
    let postId: UUID
    let authorId: UUID
    var body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case authorId = "author_id"
        case body
        case createdAt = "created_at"
    }
}

/// A like or comment from someone else on one of *your* posts — built
/// client-side from the same `likes`/`commentsByPostId` PostsStore
/// already loads (see `PostsStore.activity(onPostsAuthoredBy:)`), not a
/// separate notifications table.
struct PostActivity: Identifiable {
    enum Kind {
        case like
        case comment(body: String)
    }

    let id: String
    let postId: UUID
    let actorId: UUID
    let createdAt: Date
    let kind: Kind
}

struct PostInsert: Codable {
    let authorId: UUID
    let podId: UUID
    let body: String?

    enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case podId = "pod_id"
        case body
    }
}

struct PostPhotoInsert: Codable {
    let postId: UUID
    let url: String
    let position: Int

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case url
        case position
    }
}

struct PostCommentInsert: Codable {
    let postId: UUID
    let authorId: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case authorId = "author_id"
        case body
    }
}

//
//  Friendship.swift
//  Podz
//
//  Created by Max Prx on 26/08/2026.
//

import Foundation

/// Mirrors a row in the `friendships` table. One row per relationship —
/// its direction (`requesterId` -> `addresseeId`) only matters for who's
/// allowed to accept/decline it; once `accepted`, both sides are just
/// "friends," symmetric from there on.
struct Friendship: Codable, Identifiable, Equatable {
    let id: UUID
    let requesterId: UUID
    let addresseeId: UUID
    var status: FriendshipStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
    }

    /// The other person in this relationship, given who "you" are.
    func otherUserId(currentUserId: UUID) -> UUID {
        requesterId == currentUserId ? addresseeId : requesterId
    }
}

enum FriendshipStatus: String, Codable {
    case pending, accepted, declined
}

struct FriendshipInsert: Codable {
    let requesterId: UUID
    let addresseeId: UUID

    enum CodingKeys: String, CodingKey {
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
    }
}

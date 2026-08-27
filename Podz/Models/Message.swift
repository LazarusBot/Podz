//
//  Message.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import Foundation

/// Mirrors a row in the `messages` table — one direct message between two
/// friends. There's no separate "conversations" row: a thread is just
/// every message where the current user is either side, grouped by the
/// other participant's id (same spirit as Friendship not needing its own
/// "relationship" concept beyond the two user ids).
struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    let senderId: UUID
    let recipientId: UUID
    var body: String
    let createdAt: Date
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case body
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    /// The other person in this message, given who "you" are.
    func otherUserId(currentUserId: UUID) -> UUID {
        senderId == currentUserId ? recipientId : senderId
    }
}

struct MessageInsert: Codable {
    let senderId: UUID
    let recipientId: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case body
    }
}

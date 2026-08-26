//
//  LikeFolder.swift
//  Podz
//
//  Created by Max Prx on 23/08/2026.
//

import Foundation

struct LikeFolder: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
}

/// A folder that belongs to someone else, shared with you (read-only) —
/// same underlying `like_folders` row as `LikeFolder`, but this decode
/// also pulls `user_id` so the UI can show whose folder it is.
struct SharedFolder: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let ownerId: UUID

    enum CodingKeys: String, CodingKey {
        case id, name
        case ownerId = "user_id"
    }
}

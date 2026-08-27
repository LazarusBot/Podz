//
//  LikeFolderShare.swift
//  Podz
//
//  Created by Max Prx on 26/08/2026.
//

import Foundation

/// Mirrors a row in `like_folder_shares` — grants a friend read-only
/// access to one of your like folders. Direction only matters for RLS;
/// there's no "shared back" concept, this is one-way.
struct LikeFolderShare: Codable, Identifiable, Equatable {
    let id: UUID
    let folderId: UUID
    let ownerId: UUID
    let sharedWithId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case folderId = "folder_id"
        case ownerId = "owner_id"
        case sharedWithId = "shared_with_id"
        case createdAt = "created_at"
    }
}

struct LikeFolderShareInsert: Codable {
    let folderId: UUID
    let ownerId: UUID
    let sharedWithId: UUID

    enum CodingKeys: String, CodingKey {
        case folderId = "folder_id"
        case ownerId = "owner_id"
        case sharedWithId = "shared_with_id"
    }
}

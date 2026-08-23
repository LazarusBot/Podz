//
//  LikesStore.swift
//  Podz
//
//  Created by Max Prx on 22/08/2026.
//

import Foundation
import Combine
internal import Auth
import Supabase

@MainActor
final class LikesStore: ObservableObject {
    static let shared = LikesStore()
    
    /// pod_id → folder_id (nil = liked but not sorted into a folder yet).
    @Published private(set) var likes: [UUID: UUID?] = [:]
    @Published private(set) var folders: [LikeFolder] = []
    @Published var lastError: String?
    
    private init() {}
    
    func isLiked(_ pod: Pod) -> Bool { likes.keys.contains(pod.id) }
    func folderId(for pod: Pod) -> UUID? { likes[pod.id] ?? nil }
    
    func pods(in folderId: UUID, from allPods: [Pod]) -> [Pod] {
        allPods.filter { likes[$0.id] == folderId }
    }
    
    func fetchAll() async {
        async let likesTask: Void = fetchLikes()
        async let foldersTask: Void = fetchFolders()
        _ = await (likesTask, foldersTask)
    }
    
    private func fetchLikes() async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        do {
            let rows: [PodLikeRow] = try await supabase
                .from("pod_likes")
                .select("pod_id, folder_id")
                .eq("user_id", value: userId)
                .execute()
                .value
            likes = Dictionary(uniqueKeysWithValues: rows.map { ($0.podId, $0.folderId) })
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    private func fetchFolders() async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        do {
            folders = try await supabase
                .from("like_folders")
                .select()
                .eq("user_id", value: userId)
                .order("created_at")
                .execute()
                .value
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    /// Creates a new folder and returns it — nil on failure.
    func createFolder(name: String) async -> LikeFolder? {
        guard let userId = AuthManager.shared.session?.user.id else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        
        do {
            let folder: LikeFolder = try await supabase
                .from("like_folders")
                .insert(LikeFolderInsert(userId: userId, name: trimmed))
                .select()
                .single()
                .execute()
                .value
            folders.append(folder)
            return folder
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func deleteFolder(_ folder: LikeFolder) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        let previousFolders = folders
        let previousLikes = likes
        
        folders.removeAll { $0.id == folder.id }
        // Liked pods that were sorted into this folder become unsorted
        // rather than un-liked — matches the DB's ON DELETE SET NULL.
        for (podId, folderId) in likes where folderId == folder.id {
            likes[podId] = nil
        }
        
        do {
            try await supabase
                .from("like_folders")
                .delete()
                .eq("id", value: folder.id)
                .eq("user_id", value: userId)
                .execute()
        } catch {
            folders = previousFolders
            likes = previousLikes
            lastError = error.localizedDescription
        }
    }
    
    /// Likes a pod directly into a folder (optimistic).
    func like(_ pod: Pod, folderId: UUID?) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        likes[pod.id] = folderId
        
        do {
            try await supabase
                .from("pod_likes")
                .upsert(
                    PodLikeInsert(userId: userId, podId: pod.id, folderId: folderId),
                    onConflict: "user_id,pod_id"
                )
                .execute()
        } catch {
            likes.removeValue(forKey: pod.id)
            lastError = error.localizedDescription
        }
    }
    
    func removeLike(_ pod: Pod) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        let previous = likes[pod.id]
        likes.removeValue(forKey: pod.id)
        
        do {
            try await supabase
                .from("pod_likes")
                .delete()
                .eq("user_id", value: userId)
                .eq("pod_id", value: pod.id)
                .execute()
        } catch {
            likes[pod.id] = previous
            lastError = error.localizedDescription
        }
    }
}

struct PodLikeRow: Codable {
    let podId: UUID
    let folderId: UUID?
    enum CodingKeys: String, CodingKey {
        case podId = "pod_id"
        case folderId = "folder_id"
    }
}

struct PodLikeInsert: Codable {
    let userId: UUID
    let podId: UUID
    let folderId: UUID?
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case podId = "pod_id"
        case folderId = "folder_id"
    }
}

struct LikeFolderInsert: Codable {
    let userId: UUID
    let name: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
    }
}

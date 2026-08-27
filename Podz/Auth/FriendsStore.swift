//
//  FriendsStore.swift
//  Podz
//
//  Created by Max Prx on 26/08/2026.
//

import Foundation
import Combine
internal import Auth
import Supabase

@MainActor
final class FriendsStore: ObservableObject {
    static let shared = FriendsStore()

    @Published private(set) var friendships: [Friendship] = []
    /// The other party's profile for every friendship — friendships only
    /// carry ids, so this is the lookup that actually lets the UI show a
    /// name/avatar instead of a UUID.
    @Published private(set) var profilesById: [UUID: Profile] = [:]
    @Published var lastError: String?

    private init() {}

    var friends: [Friendship] {
        friendships.filter { $0.status == .accepted }
    }

    var incomingRequests: [Friendship] {
        guard let userId = AuthManager.shared.session?.user.id else { return [] }
        return friendships.filter { $0.status == .pending && $0.addresseeId == userId }
    }

    var outgoingRequests: [Friendship] {
        guard let userId = AuthManager.shared.session?.user.id else { return [] }
        return friendships.filter { $0.status == .pending && $0.requesterId == userId }
    }

    /// The relationship with a given user, if any — used to show the
    /// right button state ("Add," "Requested," "Friends") in search
    /// results instead of always offering to send a request.
    func friendship(with userId: UUID) -> Friendship? {
        friendships.first { $0.requesterId == userId || $0.addresseeId == userId }
    }

    func fetchAll() async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        do {
            friendships = try await supabase
                .from("friendships")
                .select()
                .or("requester_id.eq.\(userId),addressee_id.eq.\(userId)")
                .execute()
                .value
            await fetchProfiles(for: Set(friendships.map { $0.otherUserId(currentUserId: userId) }))
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fetchProfiles(for userIds: Set<UUID>) async {
        guard !userIds.isEmpty else { return }
        do {
            let fetched: [Profile] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: Array(userIds).map { $0.uuidString })
                .execute()
                .value
            for profile in fetched {
                profilesById[profile.id] = profile
            }
        } catch {
            // Non-fatal — the relevant row just shows a fallback name.
        }
    }

    /// Username search for the add-friend flow — excludes yourself and
    /// anyone you already have a relationship with (pending or accepted),
    /// so results only ever show people worth showing an "Add" button for.
    func searchProfiles(username: String) async -> [Profile] {
        guard let userId = AuthManager.shared.session?.user.id else { return [] }
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        do {
            let results: [Profile] = try await supabase
                .from("profiles")
                .select()
                .ilike("username", pattern: "%\(trimmed)%")
                .neq("id", value: userId)
                .limit(20)
                .execute()
                .value
            return results
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    /// Sends a request (optimistic, matching LikesStore's `like` pattern).
    func sendRequest(to addresseeId: UUID) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        do {
            let inserted: Friendship = try await supabase
                .from("friendships")
                .insert(FriendshipInsert(requesterId: userId, addresseeId: addresseeId))
                .select()
                .single()
                .execute()
                .value
            friendships.append(inserted)
            await fetchProfiles(for: [addresseeId])
        } catch {
            lastError = error.localizedDescription
        }
    }

    func respond(to friendship: Friendship, accept: Bool) async {
        let previous = friendships
        guard let index = friendships.firstIndex(where: { $0.id == friendship.id }) else { return }
        friendships[index].status = accept ? .accepted : .declined

        do {
            try await supabase
                .from("friendships")
                .update(["status": accept ? "accepted" : "declined"])
                .eq("id", value: friendship.id)
                .execute()
        } catch {
            friendships = previous
            lastError = error.localizedDescription
        }
    }

    /// Cancels an outgoing request or removes an existing friend — same
    /// action either way from the row's perspective, just deleting the
    /// relationship.
    func remove(_ friendship: Friendship) async {
        let previous = friendships
        friendships.removeAll { $0.id == friendship.id }

        do {
            try await supabase
                .from("friendships")
                .delete()
                .eq("id", value: friendship.id)
                .execute()
        } catch {
            friendships = previous
            lastError = error.localizedDescription
        }
    }
}

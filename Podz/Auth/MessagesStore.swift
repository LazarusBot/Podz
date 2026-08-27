//
//  MessagesStore.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import Foundation
import Combine
internal import Auth
import Supabase

/// One row per DM between two friends, same derive-don't-store pattern as
/// FriendsStore: no separate "conversations" table, a thread is just
/// `messages` grouped by the other participant's id.
@MainActor
final class MessagesStore: ObservableObject {
    static let shared = MessagesStore()

    @Published private(set) var messages: [Message] = []
    @Published var lastError: String?

    /// Guards `startRealtimeIfNeeded()` so the app only ever opens one
    /// subscription for the session, no matter how many times the
    /// Mailbox tab is revisited.
    private var didStartRealtime = false

    private init() {}

    struct Conversation: Identifiable {
        let friendId: UUID
        let lastMessage: Message?
        let unreadCount: Int
        var id: UUID { friendId }
    }

    /// One row per friend, most-recently-active first — friends with no
    /// messages yet sort to the bottom so the list still doubles as an
    /// entry point to start a conversation, same as an empty-state row.
    func conversations(friendIds: [UUID]) -> [Conversation] {
        guard let userId = AuthManager.shared.session?.user.id else { return [] }
        let grouped = Dictionary(grouping: messages) { $0.otherUserId(currentUserId: userId) }
        return friendIds
            .map { friendId -> Conversation in
                let thread = grouped[friendId] ?? []
                let last = thread.max { $0.createdAt < $1.createdAt }
                let unread = thread.filter { $0.recipientId == userId && $0.readAt == nil }.count
                return Conversation(friendId: friendId, lastMessage: last, unreadCount: unread)
            }
            .sorted { lhs, rhs in
                switch (lhs.lastMessage, rhs.lastMessage) {
                case let (l?, r?): return l.createdAt > r.createdAt
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return false
                }
            }
    }

    /// Total unread count across every conversation — drives the
    /// Mailbox tab's persistent badge (BottomTabBar), not just a single
    /// thread's own unread count.
    var unreadCount: Int {
        guard let userId = AuthManager.shared.session?.user.id else { return 0 }
        return messages.filter { $0.recipientId == userId && $0.readAt == nil }.count
    }

    /// Every message with `friendId`, oldest first — ready to render
    /// top-to-bottom in a thread.
    func thread(with friendId: UUID) -> [Message] {
        guard let userId = AuthManager.shared.session?.user.id else { return [] }
        return messages
            .filter { $0.otherUserId(currentUserId: userId) == friendId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func fetchAll() async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        do {
            messages = try await supabase
                .from("messages")
                .select()
                .or("sender_id.eq.\(userId),recipient_id.eq.\(userId)")
                .order("created_at")
                .execute()
                .value
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Sends a DM (optimistic, matching FriendsStore's `sendRequest`
    /// pattern) — the row is only insertable server-side if `recipientId`
    /// is an accepted friend, enforced by the table's RLS policy.
    func send(to recipientId: UUID, body text: String) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let optimisticId = UUID()
        messages.append(
            Message(id: optimisticId, senderId: userId, recipientId: recipientId, body: trimmed, createdAt: Date(), readAt: nil)
        )

        do {
            let inserted: Message = try await supabase
                .from("messages")
                .insert(MessageInsert(senderId: userId, recipientId: recipientId, body: trimmed))
                .select()
                .single()
                .execute()
                .value
            if let index = messages.firstIndex(where: { $0.id == optimisticId }) {
                messages[index] = inserted
            }
        } catch {
            messages.removeAll { $0.id == optimisticId }
            lastError = error.localizedDescription
        }
    }

    /// Marks every unread message from this friend as read — called when
    /// their thread is opened.
    func markRead(from friendId: UUID) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }
        let unreadIds = messages
            .filter { $0.senderId == friendId && $0.recipientId == userId && $0.readAt == nil }
            .map(\.id)
        guard !unreadIds.isEmpty else { return }

        let now = Date()
        for id in unreadIds {
            if let index = messages.firstIndex(where: { $0.id == id }) {
                messages[index].readAt = now
            }
        }

        do {
            try await supabase
                .from("messages")
                .update(["read_at": now])
                .in("id", values: unreadIds.map { $0.uuidString })
                .execute()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Subscribes to new incoming DMs so an open thread (or the list's
    /// unread badge) updates live without polling. Safe to call
    /// repeatedly — only opens the channel once per session. Outgoing
    /// sends already land optimistically in `send(to:body:)`, so this
    /// only needs to watch rows where the current user is the recipient.
    func startRealtimeIfNeeded() {
        guard !didStartRealtime, let userId = AuthManager.shared.session?.user.id else { return }
        didStartRealtime = true

        Task {
            let channel = supabase.channel("messages-inbox-\(userId.uuidString)")
            let insertions = channel.postgresChange(
                InsertAction.self,
                table: "messages",
                filter: .eq("recipient_id", value: userId)
            )

            do {
                try await channel.subscribeWithError()
            } catch {
                lastError = error.localizedDescription
                didStartRealtime = false
                return
            }

            for await insertion in insertions {
                guard let inserted = try? insertion.decodeRecord(as: Message.self, decoder: AnyJSON.decoder) else { continue }
                guard !messages.contains(where: { $0.id == inserted.id }) else { continue }
                messages.append(inserted)
            }
        }
    }
}

//
//  MailboxView.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import SwiftUI
internal import Auth

/// node 3936:257 — the Mailbox tab: one row per friend, most-recently
/// messaged first, opening into ConversationView. Reuses FriendsStore's
/// friend list + profile lookup (same data FriendsView shows) and layers
/// MessagesStore's conversation previews on top.
struct MailboxView: View {
    @StateObject private var friendsStore = FriendsStore.shared
    @StateObject private var messagesStore = MessagesStore.shared
    @StateObject private var auth = AuthManager.shared
    @State private var openFriendId: UUID?
    // Shared with HomeView — feeds the floating tab bar's scroll-down
    // shrink (MainTabView). ConversationView doesn't need this itself:
    // it hides the tab bar outright while a thread is open.
    @StateObject private var scrollState = ScrollTrackingState.shared

    var body: some View {
        Group {
            if let friendId = openFriendId, let userId = auth.session?.user.id {
                ConversationView(
                    friendId: friendId,
                    friendProfile: friendsStore.profilesById[friendId],
                    currentUserId: userId,
                    onBack: { openFriendId = nil }
                )
            } else {
                listContent
            }
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
        .task {
            await friendsStore.fetchAll()
            await messagesStore.fetchAll()
            messagesStore.startRealtimeIfNeeded()
        }
        .onAppear {
            // ScrollTrackingState is one singleton shared by every
            // scrollable tab — without this, switching in from a tab
            // scrolled down elsewhere could compute a spurious delta
            // against that stale offset and flash the tab bar's shrink
            // for a beat, unrelated to any actual scrolling here. This
            // is what read as "a small size-down spring" specifically
            // on tapping into Mailbox — its ScrollView, unlike the
            // others, only started existing once friends had loaded, so
            // this glitch was masked there until that recent change.
            scrollState.reset()
        }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            header

            // The ScrollView now wraps both branches instead of gating on
            // one — it used to only exist once `friendsStore.friends`
            // was non-empty, so `.onScrollGeometryChange` below never
            // fired to correct a stale `isScrollingDown` carried over
            // from another tab (a global singleton, not reset per-tab)
            // until friends actually finished loading, which showed up
            // as the tab bar looking "off" specifically right after
            // switching into Mailbox. Always mounting the ScrollView —
            // matching how LikesView's own empty state lives inside its
            // ScrollView rather than gating it — means there's always
            // something present to report an offset and self-correct.
            ScrollView {
                VStack(spacing: 0) {
                    if friendsStore.friends.isEmpty {
                        emptyState
                    } else if let userId = auth.session?.user.id {
                        ForEach(conversations(currentUserId: userId)) { conversation in
                            Button {
                                openFriendId = conversation.friendId
                            } label: {
                                ConversationRow(
                                    profile: friendsStore.profilesById[conversation.friendId],
                                    conversation: conversation
                                )
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(Color.appBorder.opacity(0.4))
                                .padding(.leading, 24 + 48 + 16)
                        }
                    }
                    // Room so the last row doesn't hide behind the floating tab bar.
                    Color.clear.frame(height: 120)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newValue in
                scrollState.updateOffset(newValue)
            }
        }
        .background(Color.appHomeBackground)
    }

    private func conversations(currentUserId: UUID) -> [MessagesStore.Conversation] {
        let friendIds = friendsStore.friends.map { $0.otherUserId(currentUserId: currentUserId) }
        return messagesStore.conversations(friendIds: friendIds)
    }

    private var header: some View {
        HStack {
            Color.clear.frame(width: 42, height: 42)
            Spacer()
            Text("Chat")
                .font(AppFont.pillLabel(24))
                .fontWeight(.heavy)
                .foregroundColor(.black)
            Spacer()
            AvatarView(imageName: auth.profile?.avatarURL, size: 42)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 31)
        .background(Color.appHomeBackground)
    }

    private var emptyState: some View {
        // Was Spacer()-centered top-to-bottom, which relied on being
        // the ScrollView's whole viewport — now that it's ScrollView
        // *content* (see `listContent`), a ScrollView proposes unbounded
        // height to what it contains, so those Spacers would have
        // nothing to push against and just collapse. Fixed top padding
        // instead — a fine trade for a state this rare (zero friends).
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("Add friends to start chatting.")
                .font(AppFont.regularLabel(14))
                .foregroundColor(.appTextMuted)
        }
        .padding(.top, 120)
        .frame(maxWidth: .infinity)
    }
}

private struct ConversationRow: View {
    let profile: Profile?
    let conversation: MessagesStore.Conversation

    var body: some View {
        HStack(spacing: 16) {
            AvatarView(imageName: profile?.avatarURL, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(profile?.displayName ?? "Someone")
                    .font(AppFont.pillLabelBold(16))
                    .foregroundColor(.black)
                Text(conversation.lastMessage?.body ?? "Say hi \u{1F44B}")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.appTextMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if let lastMessage = conversation.lastMessage {
                    Text(Self.relativeTime(lastMessage.createdAt))
                        .font(AppFont.regularLabel(11))
                        .foregroundColor(.appTextMuted)
                }
                if conversation.unreadCount > 0 {
                    Circle()
                        .fill(Color.appMessageBlue)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    MailboxView()
}

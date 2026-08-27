//
//  ConversationView.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import SwiftUI
import UIKit

/// node 3946:365 — a single DM thread with one friend, pushed from
/// MailboxView the same manual @State push/pop way ProfileView pushes its
/// sub-screens (this app doesn't use NavigationStack anywhere).
struct ConversationView: View {
    let friendId: UUID
    let friendProfile: Profile?
    let currentUserId: UUID
    var onBack: () -> Void

    @StateObject private var messagesStore = MessagesStore.shared
    @State private var draft = ""
    @State private var keyboardHeight: CGFloat = 0

    private var thread: [Message] {
        messagesStore.thread(with: friendId)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(thread.enumerated()), id: \.element.id) { index, message in
                            if showsDayDivider(before: index) {
                                Text(Self.dayLabel(message.createdAt))
                                    .font(AppFont.mediumLabel(10))
                                    .foregroundColor(.appTextMuted)
                                    .padding(.top, 18)
                                    .padding(.bottom, 6)
                            }
                            MessageBubble(message: message, isMine: message.senderId == currentUserId)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .onChange(of: thread.count) {
                    scrollToLast(proxy)
                }
                .onAppear {
                    scrollToLast(proxy, animated: false)
                }
            }

            composer
        }
        .padding(.bottom, keyboardHeight)
        // MainTabView wraps every tab's content in `.ignoresSafeArea(edges:
        // .bottom)` so the floating tab bar can sit flush with the home
        // indicator — but that also strips the automatic keyboard-safe-area
        // push-up from everything nested inside it, so the composer just
        // sat behind the keyboard instead of rising above it. Ignoring the
        // keyboard region explicitly (redundant with the ancestor, but
        // makes the intent local) and tracking its height ourselves below
        // is what actually keeps the send button reachable.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(Color.appHomeBackground)
        .onAppear { TabBarVisibilityState.shared.isHidden = true }
        .onDisappear { TabBarVisibilityState.shared.isHidden = false }
        .task { await messagesStore.markRead(from: friendId) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard
                let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                let screenHeight = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.screen.bounds.height })
                    .first
            else { return }
            // frame.origin.y hits screenHeight when the keyboard is fully
            // dismissed (undocked/floating keyboards report a frame that
            // doesn't reach the bottom edge at all) — either way, treat
            // anything not sitting at the bottom edge as "closed" rather
            // than trusting frame.height alone.
            let visibleHeight = frame.origin.y >= screenHeight ? 0 : frame.height
            // Deliberately faster than the system's own keyboard timing
            // (~0.25s) — matching it made the composer feel like it was
            // trailing the keyboard up rather than rising with it.
            withAnimation(.easeOut(duration: 0.15)) {
                keyboardHeight = visibleHeight
            }
        }
    }

    private func showsDayDivider(before index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.current.isDate(thread[index].createdAt, inSameDayAs: thread[index - 1].createdAt)
    }

    private func scrollToLast(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastId = thread.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
            }
            .background(Circle().fill(Color.white))
            .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))

            Spacer()

            VStack(spacing: 4) {
                AvatarView(imageName: friendProfile?.avatarURL, size: 44)
                Text(friendProfile?.displayName ?? "Someone")
                    .font(AppFont.pillLabelBold(15))
                    .foregroundColor(.black)
            }

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(Color.appHomeBackground)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $draft, axis: .vertical)
                .font(AppFont.mediumLabel(16))
                .lineLimit(1...4)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                // Apple HIG: keep every tappable control at least 44x44pt —
                // the padding above already gets close, this is the floor
                // that holds regardless of font metrics, while still
                // growing taller for Dynamic Type / multi-line drafts.
                .frame(minHeight: 44)
                .pillStyle()

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 45, height: 45)
                    .background(Circle().fill(canSend ? Color.black : Color.appBorder))
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 15)
        .background(Color.appHomeBackground)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        let text = draft
        draft = ""
        Task { await messagesStore.send(to: friendId, body: text) }
    }

    /// "Mon 18 July - 09pm" — day + time divider shown before the first
    /// message of each calendar day.
    private static func dayLabel(_ date: Date) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE d MMMM - hh"
        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "a"
        hourFormatter.amSymbol = "am"
        hourFormatter.pmSymbol = "pm"
        return dayFormatter.string(from: date) + hourFormatter.string(from: date)
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            Text(message.body)
                .font(AppFont.mediumLabel(14))
                .foregroundColor(isMine ? .white : .black)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isMine ? Color.appMessageBlue : Color.appMessageReceivedBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(isMine ? Color.appMessageBlue.opacity(0.3) : Color.appBorder, lineWidth: 0.5)
                        )
                )
            if !isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}

#Preview {
    ConversationView(friendId: UUID(), friendProfile: nil, currentUserId: UUID(), onBack: {})
}

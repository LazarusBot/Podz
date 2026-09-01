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
    @FocusState private var isDraftFocused: Bool
    /// Set by swiping a message — shown as a small removable banner above
    /// the composer and focuses the field, but doesn't tag the sent
    /// message in any way (there's no reply/thread column on `Message`);
    /// it's purely "jump into replying to this one," cleared on send or
    /// cancel.
    @State private var replyingTo: Message?

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
                            MessageBubble(message: message, isMine: message.senderId == currentUserId) {
                                replyingTo = message
                                isDraftFocused = true
                            }
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
                .contentShape(Rectangle())
                .onTapGesture { isDraftFocused = false }
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
            withAnimation(.easeOut(duration: AppMotion.quick)) {
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
        // .bottom, not the default .center — otherwise the send button
        // re-centers itself against the field's full height as it grows
        // to two rows, drifting upward instead of staying anchored where
        // your thumb expects it.
        HStack(alignment: .bottom, spacing: 10) {
            // The reply banner (when swiping a message) lives inside this
            // same pill, stacked above the field, instead of as its own
            // separate bar above the whole composer.
            VStack(alignment: .leading, spacing: 18) {
                if let replyingTo {
                    replyBanner(for: replyingTo)
                }

                TextField("", text: $draft, prompt: Text("Message").foregroundColor(Color(red: 0xAA/255, green: 0xAA/255, blue: 0xAA/255)), axis: .vertical)
                    .font(AppFont.mediumLabel(15))
                    .lineLimit(1...4)
                    .focused($isDraftFocused)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(minHeight: 50)
            // Fixed 24pt radius once the reply banner pushes this taller
            // than a single line — same reasoning as HomeSearchRow's own
            // search pill: a plain Capsule() would balloon into a stadium
            // shape at that height instead of reading as one rounded
            // container that simply grew.
            .pillStyle(cornerRadius: replyingTo != nil ? 24 : nil)
            // Bigger tap target than the pill itself actually draws —
            // `contentShape` only changes hit-testing, not layout, so
            // this doesn't shift the send button or grow anything on
            // screen. A tap that lands on the real TextField still hits
            // it directly first (for normal cursor placement); this only
            // catches the margin just outside the pill's visible edge.
            .contentShape(Rectangle().inset(by: -10))
            .onTapGesture { isDraftFocused = true }

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
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

    private func replyBanner(for message: Message) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 12))
                .foregroundColor(.appMessageBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text("Replying to \(message.senderId == currentUserId ? "yourself" : (friendProfile?.displayName ?? "them"))")
                    .font(AppFont.pillLabelBold(14))
                    .foregroundColor(.black)
                Text(message.body)
                    .font(AppFont.mediumLabel(12))
                    .foregroundColor(.appTextMuted)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { replyingTo = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.appTextMuted)
            }
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        let text = draft
        draft = ""
        replyingTo = nil
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
    var onSwipeToReply: () -> Void = {}

    /// How far the bubble has been dragged right, in points — 0 at rest.
    /// Same swipe-right-to-reply direction regardless of `isMine`, since
    /// there's more room to reveal the reply icon on the leading side for
    /// either bubble alignment.
    @State private var dragOffset: CGFloat = 0
    private let maxSwipe: CGFloat = 56
    private let replyThreshold: CGFloat = 40

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            ZStack(alignment: .leading) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.appTextMuted)
                    .opacity(Double(dragOffset / maxSwipe))
                    .offset(x: -28)

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
                    .offset(x: dragOffset)
            }
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        // Only once the drag reads as clearly horizontal —
                        // otherwise an ordinary vertical scroll through
                        // the thread gets caught here instead of reaching
                        // the ScrollView.
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let proposed = max(0, value.translation.width)
                        // Rubber-band past the max instead of hard-
                        // clamping — communicates "you can keep pulling,
                        // it just won't go further" rather than feeling
                        // like it's stuck on a wall.
                        dragOffset = proposed <= maxSwipe ? proposed : maxSwipe + (proposed - maxSwipe) * 0.2
                    }
                    .onEnded { value in
                        if value.translation.width > replyThreshold {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onSwipeToReply()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
            )

            if !isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}

#Preview {
    ConversationView(friendId: UUID(), friendProfile: nil, currentUserId: UUID(), onBack: {})
}

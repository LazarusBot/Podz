import SwiftUI

/// Lenny's side of the conversation on the search screen: the route in the
/// pill above is what you said, and this is its answer. While Lenny works the
/// bubble shows three bouncing dots; when the search is over the message
/// types itself out. Flat, in the design system's `homePill`, with Lenny's
/// mark as its avatar, which reacts to how the search went (a hop when it
/// found something, a shake of the head when it couldn't). Errors are said
/// here, by Lenny. Reduce Motion drops the bounce, the typing and the moves.
///
/// The bubble is the size of the whole message from its first letter (the
/// words appear inside it), so typing never makes it grow or the stack around
/// it shift. `isPresent` keeps the bubble in the layout but out of sight until
/// its turn, then lets it rise in and start typing; `onTyped` says when the
/// last letter is in.
struct LennyReply: View {
    /// `nil` while Lenny is still working.
    let message: String?
    /// The face on the avatar.
    var mood: LennyMood = .working
    /// Off when Lenny's mark is already on screen and the bubble speaks from it.
    var showsAvatar = true
    /// Where the bubble sits in the row: flush left, or centered.
    var alignment: Alignment = .leading

    /// False: the bubble holds its place but is hidden and silent.
    var isPresent = true
    /// Called once the whole message has been typed.
    var onTyped: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typed = ""

    private struct TypingKey: Equatable {
        let message: String?
        let isPresent: Bool
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if showsAvatar { avatar }
            bubble
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .animation(.smooth(duration: 0.3), value: message == nil)
        .opacity(isPresent ? 1 : 0)
        .offset(y: isPresent || reduceMotion ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isPresent)
        .task(id: TypingKey(message: message, isPresent: isPresent)) { await type() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.map(tr) ?? tr("Lenny is typing"))
    }

    /// An error is the one thing that turns red: Lenny's disc and the bubble.
    private var isError: Bool { mood == .sorry }

    private var avatar: some View {
        LennyMark(mood: mood)
            .foregroundColor(isError ? .onPhoto : .homeBackground)
            .frame(width: 30, height: 30)
            .background(isError ? Color.appBadgeRed : Color.homeText, in: Circle())
            .animation(.smooth(duration: 0.3), value: isError)
    }

    private var bubble: some View {
        Group {
            if message == nil {
                typingDots
            } else {
                // The whole message sizes the bubble; the typed part sits in it.
                ZStack(alignment: .topLeading) {
                    messageText(message.map(tr) ?? "")
                        .hidden()
                        .accessibilityHidden(true)
                    messageText(typed)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 46)
        .background(isError ? Color.appBadgeRed : Color.homePill, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .animation(.smooth(duration: 0.3), value: isError)
    }

    private func messageText(_ text: String) -> some View {
        Text(text)
            .font(AppFont.regularLabel(15))
            .foregroundColor(isError ? .onPhoto : .homeText)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Three dots passing a bounce along.
    private var typingDots: some View {
        LennyDots()
            .frame(height: 18)
    }

    private func type() async {
        guard let message = message.map(tr) else {
            typed = ""
            return
        }
        // Waiting for its turn: nothing typed yet.
        guard isPresent else {
            typed = ""
            return
        }
        guard !reduceMotion else {
            typed = message
            onTyped?()
            return
        }
        typed = ""
        // Let the bubble finish rising in before the first letter.
        try? await Task.sleep(nanoseconds: 150_000_000)
        for character in message {
            if Task.isCancelled { return }
            typed.append(character)
            try? await Task.sleep(nanoseconds: 24_000_000)
        }
        if !Task.isCancelled { onTyped?() }
    }
}

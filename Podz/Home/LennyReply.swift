import SwiftUI

/// Lenny's side of the conversation on the search screen: the route in the
/// pill above is what you said, and this is its answer. While Lenny works the
/// bubble shows three bouncing dots; when the search is over the message
/// types itself out. Flat, in the design system's `homePill`, with Lenny's
/// mark as its avatar, which reacts to how the search went (a hop when it
/// found something, a shake of the head when it couldn't). Errors are said
/// here, by Lenny. Reduce Motion drops the bounce, the typing and the moves.
struct LennyReply: View {
    /// `nil` while Lenny is still working.
    let message: String?
    /// The face on the avatar.
    var mood: LennyMood = .working

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typed = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            avatar
            bubble
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.3), value: message == nil)
        .task(id: message) { await type() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Lenny is typing")
    }

    private var avatar: some View {
        LennyMark(mood: mood)
            .frame(width: 15, height: 15)
            .foregroundColor(.homeBackground)
            .frame(width: 30, height: 30)
            .background(Color.homeText, in: Circle())
    }

    private var bubble: some View {
        Group {
            if message == nil {
                typingDots
            } else {
                Text(typed)
                    .font(AppFont.regularLabel(15))
                    .foregroundColor(.homeText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 46)
        .background(Color.homePill, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    /// Three dots passing a bounce along.
    private var typingDots: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = reduceMotion ? 0.6 : max(0, sin(time * 7 - Double(index) * 0.9))
                    Circle()
                        .fill(Color.homeText.opacity(0.3 + 0.5 * wave))
                        .frame(width: 7, height: 7)
                        .offset(y: -3 * wave)
                }
            }
        }
        .frame(height: 18)
    }

    private func type() async {
        guard let message else {
            typed = ""
            return
        }
        guard !reduceMotion else {
            typed = message
            return
        }
        typed = ""
        for character in message {
            if Task.isCancelled { return }
            typed.append(character)
            try? await Task.sleep(nanoseconds: 24_000_000)
        }
    }
}

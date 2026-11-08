import SwiftUI

/// Lenny's first sight: the one time he introduces himself, on the same
/// `homeBackground` ground as the launch screen. His disc arrives in the
/// middle (a soft pop), his eyes open, he blinks once and hops; then three
/// bubbles say who he is, what he does and where to find him, each rising in
/// after the last has been typed (nothing already on screen moves), and a small
/// caption, **Nice to meet you**, lets the traveler in. It plays once per
/// install (`lennyIntroSeen`); a later blink every few seconds keeps him alive
/// while the lines are read. Reduce Motion keeps the order but drops the pop,
/// the blinks and the hop.
struct LennyIntroView: View {
    /// The screen is on its way out: everything fades and drifts down.
    var isLeaving = false
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var discShown = false
    /// 0 = closed, 1 = open: the eyes' height.
    @State private var eyes = 0.05
    @State private var mood = LennyMood.idle
    /// How many bubbles have been let in.
    @State private var lines = 0
    @State private var typed = 0

    private static let discSize: CGFloat = 132
    private static let messages = [
        "Hi, I'm Lenny.",
        "I find mountain huts, plan your routes and keep track of your stays.",
        "Just describe your trip in the search bar on Home, and I'll take it from there.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)

            face
                .frame(maxWidth: .infinity)
                .padding(.bottom, 56)

            ForEach(Array(Self.messages.enumerated()), id: \.offset) { index, message in
                LennyReply(
                    message: message,
                    mood: .idle,
                    showsAvatar: false,
                    isPresent: lines > index,
                    onTyped: { typed = max(typed, index + 1) }
                )
            }

            // Always in the layout, so nothing moves when it arrives.
            Button(action: onContinue) {
                HStack(spacing: 5) {
                    T("Nice to meet you")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .underline(color: Color.homeSubtitle.opacity(0.5))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.homeSubtitle)
                }
                .padding(.vertical, 8)
                .captionTapArea()
            }
            .buttonStyle(.plain)
            .padding(.leading, 18)
            .opacity(typed >= Self.messages.count ? 1 : 0)
            .animation(.smooth(duration: 0.4), value: typed)
            .disabled(typed < Self.messages.count)
            .accessibilityHidden(typed < Self.messages.count)
        }
        .opacity(isLeaving ? 0 : 1)
        .offset(y: isLeaving && !reduceMotion ? 14 : 0)
        .padding(.horizontal, 24)
        .padding(.bottom, 40 + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.homeBackground.ignoresSafeArea())
        .task { await play() }
        .task(id: typed) { await advance() }
        .task { await blinkNow() }
    }

    /// His disc and eyes.
    private var face: some View {
        LennyMark(mood: mood)
            .scaleEffect(x: 1, y: eyes, anchor: UnitPoint(x: 0.5, y: 0.57))
            .foregroundColor(.homeBackground)
            .frame(width: Self.discSize, height: Self.discSize)
            .background(Color.homeText, in: Circle())
            .scaleEffect(discShown || reduceMotion ? 1 : 0.55)
            .opacity(discShown ? 1 : 0)
            .accessibilityLabel(tr("Lenny"))
    }

    // MARK: - The order of things

    /// Disc, eyes, blink, hop, then the first line.
    private func play() async {
        if reduceMotion {
            discShown = true
            eyes = 1
            try? await Task.sleep(for: .milliseconds(400))
            lines = 1
            return
        }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { discShown = true }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { eyes = 1 }
        try? await Task.sleep(for: .milliseconds(900))
        await blink()
        try? await Task.sleep(for: .milliseconds(350))
        mood = .happy
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        try? await Task.sleep(for: .milliseconds(250))
        lines = 1
    }

    /// The next bubble comes in a beat after the last was typed.
    private func advance() async {
        guard typed > 0, typed < Self.messages.count else { return }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 600))
        if !Task.isCancelled { lines = max(lines, typed + 1) }
    }

    /// While the lines are read, he blinks now and then.
    private func blinkNow() async {
        guard !reduceMotion else { return }
        // Not before the opening sequence is over.
        try? await Task.sleep(for: .seconds(7))
        while !Task.isCancelled {
            await blink()
            try? await Task.sleep(for: .milliseconds(Int.random(in: 3200...5200)))
        }
    }

    private func blink() async {
        withAnimation(.easeIn(duration: 0.09)) { eyes = 0.06 }
        try? await Task.sleep(for: .milliseconds(110))
        withAnimation(.easeOut(duration: 0.16)) { eyes = 1 }
    }
}

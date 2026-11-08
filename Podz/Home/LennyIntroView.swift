import SwiftUI

/// Lenny's first sight: the one time he introduces himself, on the same
/// `homeBackground` ground as the launch screen. His disc arrives in the
/// middle (a soft pop), his eyes come in, he blinks once and hops; then three
/// bubbles say who he is, what he does and where to find him, each rising in
/// after the last has been typed (nothing already on screen moves). Lenny
/// goes with them: he shrinks to his avatar beside the first bubble and
/// glides down to sit beside each new one, always next to the line being
/// typed. A small caption, **Nice to meet you**, lets the traveler in. It
/// plays once per install (`lennyIntroSeen`); a later blink every few seconds
/// keeps him alive while the lines are read. Reduce Motion keeps the order but
/// drops the pop, the glide, the blinks and the hop.
struct LennyIntroView: View {
    /// The screen is on its way out: everything fades and drifts down.
    var isLeaving = false
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var discShown = false
    /// The eyes' arrival: 0 = the disc is bare, 1 = they're there.
    @State private var eyesIn = 0.0
    /// A blink only squashes them (never to a line): 1 = open.
    @State private var blinkHeight = 1.0
    @State private var mood = LennyMood.idle
    /// How many bubbles have been let in.
    @State private var lines = 0
    @State private var typed = 0
    @Namespace private var lennySpace

    private static let discSize: CGFloat = 132
    private static let messages = [
        "Hi, I'm Lenny.",
        "I find mountain huts, plan your routes and keep track of your stays.",
        "Just describe your trip in the search bar on Home, and I'll take it from there.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)

            // Where he stands before the first line: the middle, big.
            ZStack {
                if lines == 0 { face(size: Self.discSize) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.discSize)
            .padding(.bottom, 56)

            ForEach(Array(Self.messages.enumerated()), id: \.offset) { index, message in
                HStack(alignment: .bottom, spacing: 8) {
                    // His place beside this line: he moves here when it's his turn.
                    ZStack {
                        if lines - 1 == index { face(size: 30) }
                    }
                    .frame(width: 30, height: 30)
                    LennyReply(
                        message: message,
                        mood: .idle,
                        showsAvatar: false,
                        isPresent: lines > index,
                        onTyped: { typed = max(typed, index + 1) }
                    )
                }
            }

            // Always in the layout, so nothing moves when it arrives.
            Button(action: onContinue) {
                CaptionLabel("Nice to meet you")
            }
            .buttonStyle(.plain)
            .padding(.leading, 38 + 18)
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

    /// His disc and eyes, one view that travels between his places.
    private func face(size: CGFloat) -> some View {
        LennyDisc(mood: mood, eyesScale: eyesIn, eyesHeight: blinkHeight, eyesOpacity: eyesIn)
            .matchedGeometryEffect(id: "lenny", in: lennySpace)
            .frame(width: size, height: size)
            .scaleEffect(discShown || reduceMotion ? 1 : 0.7)
            .opacity(discShown ? 1 : 0)
            .transition(.identity)
            .accessibilityLabel(tr("Lenny"))
    }

    // MARK: - The order of things

    /// Disc, eyes, blink, hop, then the first line.
    private func play() async {
        if reduceMotion {
            discShown = true
            eyesIn = 1
            try? await Task.sleep(for: .milliseconds(400))
            lines = 1
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { discShown = true }
        try? await Task.sleep(for: .milliseconds(400))
        // The eyes come in softly, from nothing.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { eyesIn = 1 }
        try? await Task.sleep(for: .milliseconds(550))
        await blink()
        try? await Task.sleep(for: .milliseconds(200))
        mood = .happy
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        try? await Task.sleep(for: .milliseconds(200))
        moveTo(line: 1)
    }

    /// The next bubble comes in a beat after the last was typed.
    private func advance() async {
        guard typed > 0, typed < Self.messages.count else { return }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 600))
        if !Task.isCancelled { moveTo(line: max(lines, typed + 1)) }
    }

    /// The next bubble rises and Lenny glides to it.
    private func moveTo(line: Int) {
        if reduceMotion {
            lines = line
        } else {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { lines = line }
        }
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
        withAnimation(.easeIn(duration: 0.07)) { blinkHeight = 0.4 }
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.easeOut(duration: 0.12)) { blinkHeight = 1 }
    }
}

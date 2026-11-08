import Combine
import SwiftUI

/// Keeps Lenny on screen long enough to say its line, even when the load is
/// instant: `start()` holds for a beat, and the launch screen waits for it
/// before saying "all good". Typing the line takes about a second.
@MainActor
final class LennyBeat: ObservableObject {
    static let duration: Duration = .milliseconds(1500)

    @Published private(set) var isHolding = false
    private var task: Task<Void, Never>?

    func start() {
        guard !isHolding else { return }
        isHolding = true
        task = Task {
            try? await Task.sleep(for: Self.duration)
            isHolding = false
        }
    }
}

/// The launch screen, in place of gray skeleton shapes: the `homeBackground`
/// ground with Lenny's bubbles at the bottom (`LennyReply`, the bubble every
/// Lenny line uses). The first asks for a moment while the session loads, by
/// the user's first name once Lenny knows it (kept from the last launch); once
/// it's ready and the line has been said, Lenny hops, a second bubble says all
/// is good, and a small caption beneath goes in. Nobody is let in before that
/// tap, the first launch of the day; the other launches that day Lenny says
/// "all good" and lets Home through by itself (`asksToContinue` off: no
/// caption). Only for a signed-in user: a signed-out one goes straight to the
/// onboarding.
///
/// It arrives and speaks without anything moving: the first bubble rises in a
/// beat after the ground, every bubble is its full size from the start (the
/// words type inside it), the second has its place held under the first, so
/// the first never shifts, and the caption only appears once "all good" has
/// been said.
struct LaunchWaitingView: View {
    /// The session is known and the first line has had its moment.
    let isReady: Bool
    /// The bubbles are on their way out: they fade and drift down.
    var isLeaving = false
    /// Lenny uses it in the first line, when it's known.
    var firstName: String? = nil
    /// The caption that goes in. Off for a later launch of the day: nothing to
    /// tap, Lenny's line is the whole screen.
    var asksToContinue = true
    /// "All good" has been said in full (a later launch lets Home through a
    /// beat after).
    var onAllGood: () -> Void = {}
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The name as it was when the screen appeared: a profile that arrives
    /// later never rewrites the line as it's being typed.
    @State private var lockedName: String?
    /// The ground has settled: the first bubble may arrive.
    @State private var started = false
    @State private var firstTyped = false
    @State private var allGoodTyped = false

    private var waitingLine: String {
        guard let lockedName else { return "One moment, I'm getting things ready." }
        return "One moment, \(lockedName). I'm getting things ready."
    }

    /// Lenny has said the first line and the session is in.
    private var showsAllGood: Bool { isReady && firstTyped }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LennyReply(
                message: waitingLine,
                mood: showsAllGood ? .happy : .working,
                isPresent: started,
                onTyped: { firstTyped = true }
            )

            // Its place is held from the start, so the first bubble stays put.
            LennyReply(
                message: "All good, you're all set.",
                mood: .idle,
                showsAvatar: false,
                isPresent: showsAllGood,
                onTyped: {
                    guard !allGoodTyped else { return }
                    allGoodTyped = true
                    onAllGood()
                }
            )
            // Lined up with the first bubble's text, past the avatar.
            .padding(.leading, 38)

            // Always in the layout, so nothing moves when the caption arrives
            // (or when there's none).
            Button(action: onContinue) {
                HStack(spacing: 5) {
                    T("Go to Home")
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
            .padding(.leading, 38 + 18)
            .opacity(allGoodTyped && asksToContinue ? 1 : 0)
            .animation(.smooth(duration: 0.4), value: allGoodTyped)
            .disabled(!allGoodTyped || !asksToContinue)
            .accessibilityHidden(!allGoodTyped || !asksToContinue)
        }
        .opacity(isLeaving ? 0 : 1)
        .offset(y: isLeaving && !reduceMotion ? 14 : 0)
        .padding(.horizontal, 24)
        // At the bottom, where Lenny's bubbles sit on every other screen: the
        // caption is where the pill row would be.
        .padding(.bottom, 40 + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.homeBackground.ignoresSafeArea())
        .onAppear { lockedName = firstName }
        .task {
            // A beat of plain ground, then Lenny arrives.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 350))
            started = true
        }
    }
}

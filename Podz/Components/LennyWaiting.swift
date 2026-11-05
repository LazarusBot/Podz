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
/// tap. Only for a signed-in user: a signed-out one goes straight to the
/// onboarding.
struct LaunchWaitingView: View {
    /// The session is known and the first line has had its moment.
    let isReady: Bool
    /// Lenny uses it in the first line, when it's known.
    /// The bubbles are on their way out: they fade and drift down.
    var isLeaving = false
    var firstName: String? = nil
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var waitingLine: String {
        guard let firstName else { return "One moment, I'm getting things ready." }
        return "One moment, \(firstName). I'm getting things ready."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LennyReply(message: waitingLine, mood: isReady ? .happy : .working)

            if isReady {
                LennyReply(message: "All good, you're all set.", mood: .idle, showsAvatar: false)
                    // Lined up with the first bubble's text, past the avatar.
                    .padding(.leading, 38)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Always in the layout, so the first bubble doesn't move when the
            // caption arrives.
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
            .opacity(isReady ? 1 : 0)
            .disabled(!isReady)
            .accessibilityHidden(!isReady)
        }
        .opacity(isLeaving ? 0 : 1)
        .offset(y: isLeaving && !reduceMotion ? 14 : 0)
        .padding(.horizontal, 24)
        // At the bottom, where Lenny's bubbles sit on every other screen: the
        // caption is where the pill row would be.
        .padding(.bottom, DetailLayout.controlStackGap + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.homeBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.35), value: isReady)
    }
}

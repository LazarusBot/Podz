import Combine
import SwiftUI

/// What the app shows while it loads, in place of gray skeleton shapes: Lenny,
/// swaying, asking for a moment (`LennyReply`, the bubble every Lenny line
/// uses). Used for the launch, before the session is known, and for the Home
/// feed while the pods arrive (only a real wait: no hold, so Lenny never shows
/// twice in a row).
struct LennyWaiting: View {
    var body: some View {
        LennyReply(message: "One moment, I'm getting things ready.", mood: .working, alignment: .center)
            .padding(.horizontal, 24)
    }
}

/// Keeps Lenny on screen long enough to say its line, even when the load is
/// instant: `start()` holds for a beat, and the launch screen shows Lenny while
/// the session loads *or* the beat is on. Typing the line takes about a second.
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

/// The launch screen: the same ground as Home, Lenny in the middle.
struct LaunchWaitingView: View {
    var body: some View {
        LennyWaiting()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.homeBackground.ignoresSafeArea())
    }
}

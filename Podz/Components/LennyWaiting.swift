import SwiftUI

/// What the app shows while it loads, in place of gray skeleton shapes: Lenny,
/// swaying, asking for a moment (`LennyReply`, the bubble every Lenny line
/// uses). Used for the launch, before the session is known, and for the Home
/// feed while the pods arrive.
struct LennyWaiting: View {
    var body: some View {
        LennyReply(message: "One moment, I'm getting things ready.", mood: .working, alignment: .center)
            .padding(.horizontal, 24)
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

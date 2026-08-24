import Foundation
import Combine

/// Whether the feed's main ScrollView is currently being scrolled down
/// (vs. up, or at rest) — shared so `MainTabView` can shrink the
/// floating tab bar while scrolling down and restore it on scroll
/// up or once scrolling goes idle for a beat.
@MainActor
final class ScrollTrackingState: ObservableObject {
    static let shared = ScrollTrackingState()

    @Published var isScrollingDown = false

    private var lastOffset: CGFloat = 0
    private var idleTask: Task<Void, Never>?

    private init() {}

    /// Feed the ScrollView's `contentOffset.y` (via `onScrollGeometryChange`)
    /// in on every change. Increases as the user scrolls down.
    func updateOffset(_ offset: CGFloat) {
        let delta = offset - lastOffset
        if delta > 6 {
            isScrollingDown = true
        } else if delta < -6 || offset < 20 {
            // Scrolling back up, or close enough to the top that
            // shrinking would just be annoying.
            isScrollingDown = false
        }
        lastOffset = offset

        // Restore full size once scrolling actually stops, even if the
        // last direction was down — don't leave it shrunk forever just
        // because the finger lifted mid-downward-scroll.
        idleTask?.cancel()
        idleTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            isScrollingDown = false
        }
    }
}

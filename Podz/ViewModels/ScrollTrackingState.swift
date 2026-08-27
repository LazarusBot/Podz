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

    /// Call from a tab's own `.onAppear` before any scroll updates come
    /// in. This is one shared singleton feeding every scrollable tab
    /// (Home, Likes, Mailbox) — without this, `lastOffset` carries over
    /// whatever the *previous* tab's scroll position was, so a freshly
    /// switched-to tab's very first offset (typically near 0) could
    /// compute a large spurious delta against that stale value and flash
    /// the tab bar's shrink for a beat right on tab entry, unrelated to
    /// any actual scrolling in the new tab.
    func reset() {
        idleTask?.cancel()
        lastOffset = 0
        isScrollingDown = false
    }

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

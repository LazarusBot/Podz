import Foundation

/// Shared animation durations, so interactions across the app pick from
/// the same small vocabulary instead of each one inventing its own
/// number (Home alone had 0.15/0.2/0.25 scattered across unrelated
/// transitions with no reasoning tying the differences together).
enum AppMotion {
    /// Small state toggles — a mode switch, a busy indicator flipping,
    /// a coachmark dismissing.
    static let quick: Double = 0.15

    /// The app's most common transition — toggling a UI element's
    /// visibility/selection (tab bar shrink, sheet row swap, badge
    /// count). Between `quick` and `standard`; was hardcoded as a bare
    /// 0.2 in ~15 places before this existed as a real third value.
    static let snappy: Double = 0.2

    /// Layout-level transitions — a panel expanding, a pill growing.
    static let standard: Double = 0.25
}

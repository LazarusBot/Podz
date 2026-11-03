import SwiftUI

extension Color {
    /// A color that actually responds to the system's light/dark setting —
    /// plain `Color(red:green:blue:)` literals (every token in
    /// AppColorsHome.swift, AppColorsNeutral.swift) render identically
    /// regardless of appearance without this, since they carry no
    /// trait-based provider at all.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// The app's gray scale, consolidated — every value here used to be a
/// bare `Color(white: 0.NN)` invented fresh at its own call site, each
/// with no name tying it to the others or to the rest of the design
/// system. Light-mode values are unchanged (same numbers, just named);
/// dark-mode values are new.
extension Color {
    /// Icon-button circle/capsule background (close buttons, the decline
    /// button on friend requests, PodDetailView's altitude/beds capsule) —
    /// was `Color(white: 0.93)`, identical at all 10 call sites.
    static let appIconButtonBackground = Color(
        light: Color(white: 0.93),
        dark: Color(white: 0.22)
    )

}

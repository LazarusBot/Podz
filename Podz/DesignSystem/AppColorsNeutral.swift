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

    /// PodDetailView's secondary detail text — region/country, altitude,
    /// "No rooms listed yet" — was `Color(white: 0.67)`.
    static let appTextSubtle = Color(
        light: Color(white: 0.67),
        dark: Color(white: 0.6)
    )

    /// PodDetailView's "Find us quickly in the wild" section heading —
    /// was `Color(white: 0.35)`.
    static let appSectionHeadingMuted = Color(
        light: Color(white: 0.35),
        dark: Color(white: 0.75)
    )

    /// LennyJourneyProgress's unresolved-stop icon/label — was
    /// `Color(white: 0.8)`.
    static let appJourneyUnresolvedIcon = Color(
        light: Color(white: 0.8),
        dark: Color(white: 0.45)
    )

    /// LennyJourneyProgress's unresolved-stop ring stroke/fill — was
    /// `Color(white: 0.85)`.
    static let appJourneyUnresolvedRing = Color(
        light: Color(white: 0.85),
        dark: Color(white: 0.35)
    )
}

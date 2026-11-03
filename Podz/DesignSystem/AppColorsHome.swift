import SwiftUI

/// Additional color tokens for the Home feed, on top of AppColorsAuth.swift
/// (auth flow). Dark values via `Color(light:dark:)` (AppColorsNeutral.swift) —
/// plain `Color(red:green:blue:)` alone never responds to system appearance.
extension Color {
    /// #FBFBFB light / #121212 dark — app background (slightly different
    /// from the #F9F9F9 used on the Filters panel — Figma uses both, keep
    /// them distinct)
    static let appHomeBackground = Color(
        light: Color(red: 0xFB/255, green: 0xFB/255, blue: 0xFB/255),
        dark: Color(red: 0x12/255, green: 0x12/255, blue: 0x12/255)
    )

    /// #8E9099 light / #9B9DA6 dark — muted gray for "Good morning," and
    /// timestamps
    static let appTextMuted = Color(
        light: Color(red: 0x8E/255, green: 0x90/255, blue: 0x99/255),
        dark: Color(red: 0x9B/255, green: 0x9D/255, blue: 0xA6/255)
    )

}

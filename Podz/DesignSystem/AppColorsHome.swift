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

    /// #EFEFEF light / #2C2C2E dark — hairline border around the whole
    /// screen container
    static let appHairline = Color(
        light: Color(red: 0xEF/255, green: 0xEF/255, blue: 0xEF/255),
        dark: Color(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255)
    )

    /// #8E9099 light / #9B9DA6 dark — muted gray for "Good morning," and
    /// timestamps
    static let appTextMuted = Color(
        light: Color(red: 0x8E/255, green: 0x90/255, blue: 0x99/255),
        dark: Color(red: 0x9B/255, green: 0x9D/255, blue: 0xA6/255)
    )

    /// #5AAF00 — green "beds still available" indicator. Same in both
    /// modes: already light/saturated enough to read on a dark background.
    static let appAvailableGreen = Color(red: 0x5A/255, green: 0xAF/255, blue: 0x00/255)

    /// #3985FF — sent-message bubble fill and the Mailbox unread dot.
    /// Same in both modes, for the same reason as `appAvailableGreen`.
    static let appMessageBlue = Color(red: 0x39/255, green: 0x85/255, blue: 0xFF/255)

    /// #F9F9F9 light / #1C1C1E dark — received-message bubble fill
    /// (Mailbox thread) — needs to stay a visibly distinct surface from
    /// the screen background behind it in both modes.
    static let appMessageReceivedBg = Color(
        light: Color(red: 0xF9/255, green: 0xF9/255, blue: 0xF9/255),
        dark: Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255)
    )
}

import SwiftUI

/// Additional color tokens for the Home feed, on top of AppColors.swift
/// (Filters) and AppColorsAuth.swift (auth flow).
extension Color {
    /// #FBFBFB — app background (slightly different from the #F9F9F9 used
    /// on the Filters panel — Figma uses both, keep them distinct)
    static let appHomeBackground = Color(red: 0xFB/255, green: 0xFB/255, blue: 0xFB/255)

    /// #EFEFEF — hairline border around the whole screen container
    static let appHairline = Color(red: 0xEF/255, green: 0xEF/255, blue: 0xEF/255)

    /// #8E9099 — muted gray for "Good morning," and timestamps
    static let appTextMuted = Color(red: 0x8E/255, green: 0x90/255, blue: 0x99/255)

    /// #5AAF00 — green "beds still available" indicator
    static let appAvailableGreen = Color(red: 0x5A/255, green: 0xAF/255, blue: 0x00/255)

    /// #3985FF — sent-message bubble fill and the Mailbox unread dot
    static let appMessageBlue = Color(red: 0x39/255, green: 0x85/255, blue: 0xFF/255)

    /// #F9F9F9 — received-message bubble fill (Mailbox thread)
    static let appMessageReceivedBg = Color(red: 0xF9/255, green: 0xF9/255, blue: 0xF9/255)
}

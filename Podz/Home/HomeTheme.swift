import SwiftUI

/// Colors for the minimalist Home (Paper "Home/dark" + "Home/white"): pure
/// black / white ground, flat grey pills, no accent — the photos carry the
/// color. Each token flips with the system appearance.
extension Color {
    /// #FFFFFF light / #000000 dark — the screen ground.
    static let homeBackground = Color(light: .white, dark: .black)

    /// #000000 light / #FFFFFF dark — titles and icon glyphs.
    static let homeText = Color(light: .black, dark: .white)

    /// #F1F1F1 light / #323232 dark — the search pill and the tab bar.
    static let homePill = Color(
        light: Color(white: 0xF1 / 255),
        dark: Color(white: 0x32 / 255)
    )

    /// #989898 light / #A0A0A0 dark — subtitles, "See all", placeholders.
    static let homeSubtitle = Color(
        light: Color(white: 0x98 / 255),
        dark: Color(white: 0xA0 / 255)
    )
}

extension Color {
    /// Placeholder on the focused (inverted) search bar — #A0A0A0 on both
    /// the black light-mode bar and the white dark-mode bar (Paper Home2).
    static let homeSubtitleOnInverse = Color(white: 0xA0 / 255)
}

extension Color {
    /// #989898 light / white 88% dark — body copy under a title (Paper
    /// DetailView frames).
    static let homeBodyText = Color(
        light: Color(white: 0x98 / 255),
        dark: Color.white.opacity(0.88)
    )
}

extension Color {
    /// Red for what can cancel the trip (a closed hut): a light red fill with a
    /// dark red ink, flipped in dark mode. Errors keep `appBadgeRed`.
    /// #FCE4E4 light / #4A1E1E dark — the chip's fill.
    static let alertFill = Color(
        light: Color(red: 0xFC / 255, green: 0xE4 / 255, blue: 0xE4 / 255),
        dark: Color(red: 0x4A / 255, green: 0x1E / 255, blue: 0x1E / 255)
    )

    /// #A31616 light / #FF9C9C dark — its label, dot and outline.
    static let alertInk = Color(
        light: Color(red: 0xA3 / 255, green: 0x16 / 255, blue: 0x16 / 255),
        dark: Color(red: 0xFF / 255, green: 0x9C / 255, blue: 0x9C / 255)
    )
}

extension Color {
    /// Marks and text laid over a photo (the pager dots, a check on a tile,
    /// the white name on a scrim): white in both modes, because a photo
    /// doesn't change with the appearance.
    static let onPhoto = Color.white

    /// The soft veil under a name on a photo, a pin's outline, a dimmer over an
    /// avatar while it uploads: black in both modes, used at partial opacity.
    static let photoScrim = Color.black

    /// A ticket's barcode paper: white in both modes, because dark bars on a
    /// light ground are what scan.
    static let barcodePaper = Color.white
}

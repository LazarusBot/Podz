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
    /// Placeholder on the focused (inverted) search bar — #A0A0A0 on the
    /// black light-mode bar, #767676 on the white dark-mode bar.
    static let homeSubtitleOnInverse = Color(
        light: Color(white: 0xA0 / 255),
        dark: Color(white: 0x76 / 255)
    )
}

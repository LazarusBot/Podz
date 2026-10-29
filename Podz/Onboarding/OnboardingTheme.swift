import SwiftUI

/// Colors for the minimalist onboarding (Figma "Onboarding" frames, dark +
/// white). Pure black / white grounds with flat grey pills — no accent
/// color, the photos carry all of it. Each token flips with the system
/// appearance, same `Color(light:dark:)` approach as the rest of the app.
extension Color {
    /// #FFFFFF light / #000000 dark — the screen ground.
    static let onbBackground = Color(light: .white, dark: .black)

    /// #000000 light / #FFFFFF dark — titles and icon glyphs.
    static let onbText = Color(light: .black, dark: .white)

    /// #989898 light / white 88% dark — subtitles and captions.
    static let onbSubtitle = Color(
        light: Color(white: 0x98 / 255),
        dark: Color.white.opacity(0.88)
    )

    /// #F1F1F1 light / #323232 dark — every pill (buttons and fields).
    static let onbPill = Color(
        light: Color(white: 0xF1 / 255),
        dark: Color(white: 0x32 / 255)
    )

    /// Hairline around a pill — the ground color, so it reads as a gap.
    static let onbPillBorder = Color(light: .white, dark: .black)

    /// The highlighted pill ("Get started") — inverts the ground.
    static let onbHighlight = Color(light: .black, dark: .white)
    static let onbHighlightText = Color(light: .white, dark: .black)

    /// Faint frames behind the welcome collage photos. Invisible in light
    /// mode, where the design draws them white on white.
    static let onbCollageOutline = Color(
        light: .clear,
        dark: Color.white.opacity(0.25)
    )
}

/// Type for the onboarding — Inter throughout, per the Figma frames.
enum OnboardingFont {
    static let title = AppFont.semiBoldLabel(20)
    static let body = AppFont.regularLabel(16)
    static let compact = AppFont.regularLabel(14)
    static let caption = AppFont.regularLabel(13)
    static let highlightedPill = AppFont.semiBoldLabel(14)
}

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

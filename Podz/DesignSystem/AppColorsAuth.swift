import SwiftUI

/// Color tokens for the auth flow (Welcome / Login / Register /
/// PostRegisterOnboarding), on top of AppColors.swift and AppColorsHome.swift.
extension Color {
    static let appPlaceholder = Color.black.opacity(0.25)
    static let appLinkGreen = Color(red: 0xC4/255, green: 0xFF/255, blue: 0xC9/255)
    static let appWhite88 = Color.white.opacity(0.88)
    static let appFieldBg = Color.white.opacity(0.99)
}

/// Fallback background shown across the auth flow when a step's image
/// asset is missing.
extension LinearGradient {
    static let appAuthImageFallback = LinearGradient(
        colors: [Color(red: 0.1, green: 0.3, blue: 0.4), .black],
        startPoint: .top, endPoint: .bottom
    )
}

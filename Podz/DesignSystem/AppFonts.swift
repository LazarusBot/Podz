import SwiftUI
import UIKit

/// Typography tokens extracted from Figma.
///
/// The design uses two font families:
/// - "Darker Grotesque" (Black weight) — pill labels and large numbers
/// - "Inter" (Bold/Medium) — list titles and helper text
///
/// **Custom Fonts Setup (Optional for pixel-perfect design):**
/// 1. Download "Darker Grotesque" and "Inter" from fonts.google.com
/// 2. Drag the .ttf files into Xcode (check "Copy items if needed")
/// 3. Add them to Info.plist under "Fonts provided by application" (`UIAppFonts`)
/// 4. These functions automatically detect and use custom fonts with fallbacks to SF Pro
///
/// The app works perfectly fine with system fonts alone—custom fonts are purely optional.
enum AppFont {
    static let darkerGrotesqueAvailable = UIFont.familyNames.contains { $0.contains("Darker Grotesque") }
    static let interAvailable = UIFont.familyNames.contains { $0.contains("Inter") }

    /// Big pill labels ("Slovenia", "Filters", stepper values) — 14pt Black
    static func pillLabel(_ size: CGFloat = 14) -> Font {
        darkerGrotesqueAvailable
            ? .custom("DarkerGrotesque-Black", size: size)
            : .system(size: size, weight: .black)
    }
    
    static func mediumLabel(_ size: CGFloat = 14) -> Font {
        darkerGrotesqueAvailable
            ? .custom("Inter-Medium", size: size)
            : .system(size: size, weight: .medium)
    }

    /// Stepper big number ("0", "3") — 20pt Black
    static func stepperValue(_ size: CGFloat = 20) -> Font {
        darkerGrotesqueAvailable
            ? .custom("DarkerGrotesque-Black", size: size)
            : .system(size: size, weight: .black)
    }

    /// List item title ("Hikers", "Wifi", "Pets") — 10pt Bold
    static func itemTitle(_ size: CGFloat = 10) -> Font {
        interAvailable
            ? .custom("Inter-Bold", size: size)
            : .system(size: size, weight: .bold)
    }

    /// List item helper text ("Number of hikers with you.") — 8pt Medium
    static func itemHelper(_ size: CGFloat = 8) -> Font {
        interAvailable
            ? .custom("Inter-Medium", size: size)
            : .system(size: size, weight: .medium)
    }
}

import SwiftUI
import UIKit
import CoreText

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

    /// Big pill labels ("Slovenia", "Filters", stepper values) — 14pt Black
    static func pillLabel(_ size: CGFloat = 14) -> Font {
        darkerGrotesqueAvailable
            ? .custom("DarkerGrotesque-Black", size: size)
            : .system(size: size, weight: .black)
    }

    /// Medium variant of the pill label — used for inactive category
    /// chips, where the Black weight is reserved for the selected state.
    static func pillLabelMedium(_ size: CGFloat = 14) -> Font {
        darkerGrotesqueAvailable
            ? .custom("DarkerGrotesque-Medium", size: size)
            : .system(size: size, weight: .medium)
    }

    /// Bold (not Black) variant of the pill label — used for section
    /// titles and pod names, one step down from Black-weight text like
    /// the "@username" header or active category pills.
    static func pillLabelBold(_ size: CGFloat = 14) -> Font {
        darkerGrotesqueAvailable
            ? .custom("DarkerGrotesque-Bold", size: size)
            : .system(size: size, weight: .bold)
    }

    /// SemiBold variant — matches the Figma auth screens' text field
    /// input/placeholder and the "or" divider (Darker Grotesque SemiBold).
    static func pillLabelSemiBold(_ size: CGFloat = 14) -> Font {
        darkerGrotesqueAvailable
            ? .custom("DarkerGrotesque-SemiBold", size: size)
            : .system(size: size, weight: .semibold)
    }

    /// Regular variant — the lightest weight, used for small de-emphasized
    /// captions like a promo card's date-range eyebrow label.
    static func pillLabelRegular(_ size: CGFloat = 14) -> Font {
        darkerGrotesqueAvailable
            ? .custom("DarkerGrotesque-Regular", size: size)
            : .system(size: size, weight: .regular)
    }
    
    static func mediumLabel(_ size: CGFloat = 14) -> Font {
        interVariable(size: size, weight: 500)
    }

    /// Real Inter at SemiBold (600) — one step up from `mediumLabel`'s
    /// 500, for a name that needs to read as clearly bolder than the
    /// regular-weight text next to it (e.g. a comment's author name
    /// above its own body) without going as heavy as a genuine Bold.
    static func semiBoldLabel(_ size: CGFloat = 14) -> Font {
        interVariable(size: size, weight: 600)
    }

    /// Real Inter, but at Regular (400) — for spots that had been
    /// silently rendering as plain SF Pro this whole time (Profile's
    /// rows, `SectionLabel`) thanks to the `.custom("Inter-X", ...)` bug
    /// `interVariable` fixes elsewhere. That accidental system-font look
    /// read as lighter/more elegant than genuine Inter at Medium/Bold, so
    /// this is the closer match — real Inter, just a lighter weight,
    /// rather than falling back to the system font outright.
    static func regularLabel(_ size: CGFloat = 14) -> Font {
        interVariable(size: size, weight: 400)
    }

    /// Stepper big number ("0", "3") — 20pt Black
    static func stepperValue(_ size: CGFloat = 20) -> Font {
        darkerGrotesqueAvailable
            ? .custom("DarkerGrotesque-Black", size: size)
            : .system(size: size, weight: .black)
    }

    /// List item title ("Hikers", "Wifi", "Pets") — 10pt Bold
    static func itemTitle(_ size: CGFloat = 10) -> Font {
        interVariable(size: size, weight: 700)
    }

    /// List item helper text ("Number of hikers with you.") — 8pt Medium
    static func itemHelper(_ size: CGFloat = 8) -> Font {
        interVariable(size: size, weight: 500)
    }

    /// `wght` as a four-character font-variation axis tag, packed into a
    /// `UInt32` the way CoreText expects (`0x77 'w' 67 'g' 68 'h' 74 't'`).
    private static let interWeightAxis: UInt32 = 0x77676874

    /// Addresses one weight of the "Inter" variable font by its real
    /// `wght` axis value (100...900) instead of a separate named font —
    /// the shipped file (`Inter-VariableFont_opsz,wght.ttf`) only
    /// registers a single PostScript name, "Inter-Regular". Its `fvar`
    /// table does list named instances for Medium/SemiBold/Bold/etc.,
    /// but none of them carry a PostScript name of their own (verified
    /// with fontTools), so `.custom("Inter-Bold", size:)` and friends
    /// were silently failing to resolve to anything and falling back to
    /// the same system font every time, regardless of which "Inter-X"
    /// name was requested — which is why changing weight visibly did
    /// nothing. This builds the real weight directly off the variable
    /// font's own axis instead.
    private static func interVariable(size: CGFloat, weight: CGFloat) -> Font {
        guard let base = UIFont(name: "Inter-Regular", size: size) else {
            return .system(size: size, weight: .regular)
        }
        let descriptor = base.fontDescriptor.addingAttributes([
            .init(rawValue: kCTFontVariationAttribute as String): [interWeightAxis: weight]
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }
}

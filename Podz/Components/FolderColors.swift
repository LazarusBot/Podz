import SwiftUI

/// The six drawer colors a Likes folder can wear (Paper-free for now: taken
/// from the drawer-cabinet reference). Flat, a touch deeper in dark mode so
/// they don't glow on black. A folder keeps the same color for good: it's
/// picked from the folder's id.
enum FolderColor: CaseIterable {
    case cream, yellow, red, green, blue, grey

    var color: Color {
        switch self {
        case .cream: Color(light: Color(red: 0xEA / 255, green: 0xDF / 255, blue: 0xC8 / 255), dark: Color(red: 0x6B / 255, green: 0x62 / 255, blue: 0x4C / 255))
        case .yellow: Color(light: Color(red: 0xF2 / 255, green: 0xC2 / 255, blue: 0x30 / 255), dark: Color(red: 0xB8 / 255, green: 0x90 / 255, blue: 0x1C / 255))
        case .red: Color(light: Color(red: 0xD6 / 255, green: 0x45 / 255, blue: 0x45 / 255), dark: Color(red: 0xA8 / 255, green: 0x35 / 255, blue: 0x35 / 255))
        case .green: Color(light: Color(red: 0x2E / 255, green: 0x8B / 255, blue: 0x57 / 255), dark: Color(red: 0x23 / 255, green: 0x6B / 255, blue: 0x44 / 255))
        case .blue: Color(light: Color(red: 0x35 / 255, green: 0x52 / 255, blue: 0xB8 / 255), dark: Color(red: 0x2B / 255, green: 0x41 / 255, blue: 0x8F / 255))
        case .grey: Color(light: Color(red: 0xA7 / 255, green: 0xAD / 255, blue: 0xB5 / 255), dark: Color(red: 0x5C / 255, green: 0x61 / 255, blue: 0x68 / 255))
        }
    }

    /// Stable for a given folder.
    static func forFolder(_ id: UUID?) -> FolderColor {
        guard let id else { return .blue }
        let sum = id.uuid.0 &+ id.uuid.5 &+ id.uuid.10 &+ id.uuid.15
        return allCases[Int(sum) % allCases.count]
    }
}

extension Color {
    /// The label tag on a drawer: paper with dark ink, in both modes.
    static let folderTagPaper = Color(light: .white, dark: Color(white: 0.93))
    static let folderTagInk = Color.black
    static let folderTagSubtitle = Color(white: 0.45)
}

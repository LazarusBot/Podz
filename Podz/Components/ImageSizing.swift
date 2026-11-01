import Foundation

/// Wikimedia Commons serves a photo at any of a few standard widths, so a card
/// can ask for the size it shows instead of the big one the database holds
/// (1280 px): about half the bytes to download and decode for a 300 pt card.
/// Other hosts' photos are left alone.
enum ImageSizing {
    /// The widths Wikimedia produces.
    private static let standardWidths = [250, 330, 500, 960, 1280, 1920]

    /// `url` at the smallest standard width that still covers `width` pixels.
    static func sized(_ url: String?, toCover width: Int) -> String? {
        guard let url, url.contains("wikimedia.org"),
              let regex = try? NSRegularExpression(pattern: "/(\\d+)px-([^/?]+)"),
              let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
              let numberRange = Range(match.range(at: 1), in: url),
              let current = Int(url[numberRange]) else { return url }
        let wanted = standardWidths.first { $0 >= width } ?? standardWidths[standardWidths.count - 1]
        // Never ask for more than what's stored.
        let target = min(wanted, current)
        guard target != current, let whole = Range(match.range, in: url), let name = Range(match.range(at: 2), in: url) else { return url }
        return url.replacingCharacters(in: whole, with: "/\(target)px-\(url[name])")
    }
}

import Foundation

/// Helpers for a listed hut's contact details (used by the detail's Contact
/// section and by Lenny's booking message).
func hutClean(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
}

/// A website without its scheme ("refuge.com") still opens.
func hutWebURL(_ link: String) -> URL? {
    URL(string: link.hasPrefix("http") ? link : "https://\(link)")
}

struct HutContactLink {
    let label: String
    let value: String
    let url: URL
}

extension Pod {
    /// Phone, email and website, whichever the hut has, ready to open.
    var contactLinks: [HutContactLink] {
        var links: [HutContactLink] = []
        if let phone = hutClean(phone), let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
            links.append(HutContactLink(label: "Phone", value: phone, url: url))
        }
        if let email = hutClean(email), let url = URL(string: "mailto:\(email)") {
            links.append(HutContactLink(label: "Email", value: email, url: url))
        }
        if let site = hutClean(bookingURL) ?? hutClean(website), let url = hutWebURL(site) {
            let shown = site.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
            links.append(HutContactLink(label: "Website", value: shown, url: url))
        }
        return links
    }
}

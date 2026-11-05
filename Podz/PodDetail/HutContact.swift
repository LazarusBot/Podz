import SwiftUI

/// How to book a listed hut: through the hut itself. Shows whichever of phone,
/// email and website it has as a short list of choices, and opens the right app.
struct HutContactDialog: ViewModifier {
    let pod: Pod
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.confirmationDialog(tr("Book through \(pod.name)"), isPresented: $isPresented, titleVisibility: .visible) {
            if let phone = clean(pod.phone), let url = hutPhoneURL(phone) {
                Button(tr("Call \(phone)")) { HutContactTracker.shared.didContact(pod); openURL(url) }
            }
            if let email = clean(pod.email), let url = hutMailURL(email, subject: "Booking request") {
                Button(tr("Email \(email)")) { HutContactTracker.shared.didContact(pod); openURL(url) }
            }
            if let link = clean(pod.bookingURL) ?? clean(pod.website), let url = Self.webURL(link) {
                Button(clean(pod.bookingURL) != nil ? "Open the booking page" : "Open the website") { HutContactTracker.shared.didContact(pod); openURL(url) }
            }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            T("This hut takes bookings itself. Mention the dates and how many of you there are.")
        }
    }

    private func clean(_ value: String?) -> String? { hutClean(value) }

    private static func webURL(_ link: String) -> URL? { hutWebURL(link) }
}

extension View {
    /// The "Book through the hut" choices for a listed pod.
    func hutContactDialog(for pod: Pod, isPresented: Binding<Bool>) -> some View {
        modifier(HutContactDialog(pod: pod, isPresented: isPresented))
    }
}

/// Helpers for a listed hut's contact details (also used by the detail's
/// Contact section).
func hutClean(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
}

/// The hut's data comes from OpenStreetMap or a host, so it is never trusted
/// as a URL: each builder below only ever makes its own scheme, and anything
/// that doesn't fit gives no link (the row is then shown without a chevron).
private let hutFieldLimit = 320

/// A website without its scheme ("refuge.com") still opens. Only http and
/// https with a real host; any other scheme ("javascript:", "sms:",
/// another app's) is refused.
func hutWebURL(_ link: String) -> URL? {
    guard link.count <= 2_000 else { return nil }
    let lower = link.lowercased()
    let hasScheme = lower.hasPrefix("http://") || lower.hasPrefix("https://")
    if !hasScheme, link.contains("://") { return nil }
    guard let components = URLComponents(string: hasScheme ? link : "https://\(link)"),
          let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
          let host = components.host, !host.isEmpty, host.contains("."),
          components.user == nil, components.password == nil
    else { return nil }
    return components.url
}

/// `tel:` with only what a dialler understands: digits and a leading +.
/// Pauses, USSD codes (* #) and anything else are dropped.
func hutPhoneURL(_ phone: String) -> URL? {
    guard phone.count <= hutFieldLimit else { return nil }
    var digits = phone.filter { $0.isASCII && $0.isNumber }
    if phone.trimmingCharacters(in: .whitespaces).hasPrefix("+") { digits = "+" + digits }
    guard digits.filter(\.isNumber).count >= 4 else { return nil }
    return URL(string: "tel:\(digits)")
}

/// `mailto:` for one plain address: no extra recipients, headers or body
/// smuggled in through "?" or "&", and the subject is encoded by us.
func hutMailURL(_ email: String, subject: String? = nil) -> URL? {
    guard email.count <= hutFieldLimit,
          email.range(of: #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    else { return nil }
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = email
    if let subject { components.queryItems = [URLQueryItem(name: "subject", value: subject)] }
    return components.url
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
        if let phone = hutClean(phone), let url = hutPhoneURL(phone) {
            links.append(HutContactLink(label: "Phone", value: phone, url: url))
        }
        if let email = hutClean(email), let url = hutMailURL(email) {
            links.append(HutContactLink(label: "Email", value: email, url: url))
        }
        if let site = hutClean(bookingURL) ?? hutClean(website), let url = hutWebURL(site) {
            let shown = site.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
            links.append(HutContactLink(label: "Website", value: shown, url: url))
        }
        return links
    }
}

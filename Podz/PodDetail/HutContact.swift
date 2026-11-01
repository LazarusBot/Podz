import SwiftUI

/// How to book a listed hut: through the hut itself. Shows whichever of phone,
/// email and website it has as a short list of choices, and opens the right app.
struct HutContactDialog: ViewModifier {
    let pod: Pod
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.confirmationDialog("Book through \(pod.name)", isPresented: $isPresented, titleVisibility: .visible) {
            if let phone = clean(pod.phone), let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
                Button("Call \(phone)") { HutContactTracker.shared.didContact(pod); openURL(url) }
            }
            if let email = clean(pod.email), let url = URL(string: "mailto:\(email)?subject=Booking%20request") {
                Button("Email \(email)") { HutContactTracker.shared.didContact(pod); openURL(url) }
            }
            if let link = clean(pod.bookingURL) ?? clean(pod.website), let url = Self.webURL(link) {
                Button(clean(pod.bookingURL) != nil ? "Open the booking page" : "Open the website") { HutContactTracker.shared.didContact(pod); openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This hut takes bookings itself. Mention the dates and how many of you there are.")
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

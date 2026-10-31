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
                Button("Call \(phone)") { openURL(url) }
            }
            if let email = clean(pod.email), let url = URL(string: "mailto:\(email)?subject=Booking%20request") {
                Button("Email \(email)") { openURL(url) }
            }
            if let link = clean(pod.bookingURL) ?? clean(pod.website), let url = Self.webURL(link) {
                Button(clean(pod.bookingURL) != nil ? "Open the booking page" : "Open the website") { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This hut takes bookings itself. Mention the dates and how many of you there are.")
        }
    }

    private func clean(_ value: String?) -> String? { hutClean(value) }

    private static func webURL(_ link: String) -> URL? { hutWebURL(link) }
}

func hutClean(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
}

/// A website without its scheme ("refuge.com") still opens.
func hutWebURL(_ link: String) -> URL? {
    URL(string: link.hasPrefix("http") ? link : "https://\(link)")
}

extension View {
    /// The "Book through the hut" choices for a listed pod.
    func hutContactDialog(for pod: Pod, isPresented: Binding<Bool>) -> some View {
        modifier(HutContactDialog(pod: pod, isPresented: isPresented))
    }
}

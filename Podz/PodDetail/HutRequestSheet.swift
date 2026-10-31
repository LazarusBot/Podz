import SwiftUI

/// "Book through the hut", with Lenny's help: a listed hut takes bookings
/// itself, so Lenny asks how many you are and when, writes the message (in
/// French for a French hut) and hands it to email, or copies it for a call.
struct HutRequestSheet: View {
    let pod: Pod
    var onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var guests = 2
    @State private var arrival = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var nights = 1
    @State private var copied = false

    private var message: String {
        HutMessage.text(pod: pod, guests: guests, arrival: arrival, nights: nights)
    }

    private var email: String? { hutClean(pod.email) }
    private var phone: String? { hutClean(pod.phone) }
    private var website: String? { hutClean(pod.bookingURL) ?? hutClean(pod.website) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    LennyReply(
                        message: "\(pod.name) takes bookings itself. Tell me who's coming and when, and I'll write the message.",
                        mood: .happy
                    )

                    VStack(spacing: 0) {
                        stepperRow("Guests", value: $guests, range: 1...20, unit: guests == 1 ? "guest" : "guests")
                        dateRow
                        stepperRow("Nights", value: $nights, range: 1...7, unit: nights == 1 ? "night" : "nights")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your message")
                            .font(AppFont.regularLabel(13))
                            .foregroundColor(.homeSubtitle)
                        Text(message)
                            .font(AppFont.regularLabel(15))
                            .lineSpacing(4)
                            .foregroundColor(.homeText)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.homePill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if phone != nil { caption("Call the hut") { call() } }
                        if website != nil { caption("Open the website") { openWebsite() } }
                        if email != nil { caption(copied ? "Copied" : "Copy the message") { copyMessage() } }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 190)
            }
            .scrollIndicators(.hidden)

            BottomFade()

            HStack(spacing: 13) {
                DetailBackButton(action: onClose)
                if email != nil {
                    DetailTextButton(title: "Send by email", isHighlighted: true, action: sendEmail)
                } else {
                    DetailTextButton(title: copied ? "Copied" : "Copy message", isHighlighted: true, action: copyMessage)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: copied) { _, now in now }
    }

    // MARK: - Rows

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(AppFont.regularLabel(16))
                .foregroundColor(.homeText)
            Spacer(minLength: 12)
            stepButton("minus", enabled: value.wrappedValue > range.lowerBound) { value.wrappedValue -= 1 }
            Text("\(value.wrappedValue) \(unit)")
                .font(AppFont.semiBoldLabel(16))
                .foregroundColor(.homeText)
                .frame(minWidth: 84)
                .contentTransition(.numericText())
            stepButton("plus", enabled: value.wrappedValue < range.upperBound) { value.wrappedValue += 1 }
        }
        .frame(height: 60)
        .overlay(alignment: .top) { Rectangle().fill(Color.homeText.opacity(0.08)).frame(height: 1) }
        .animation(.smooth(duration: 0.2), value: value.wrappedValue)
    }

    private var dateRow: some View {
        HStack {
            Text("Arrival")
                .font(AppFont.regularLabel(16))
                .foregroundColor(.homeText)
            Spacer()
            DatePicker("Arrival", selection: $arrival, in: Date()..., displayedComponents: .date)
                .labelsHidden()
                .tint(.homeText)
        }
        .frame(height: 60)
        .overlay(alignment: .top) { Rectangle().fill(Color.homeText.opacity(0.08)).frame(height: 1) }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.homeText)
                .frame(width: 38, height: 38)
                .background(Color.homePill, in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }

    private func caption(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .underline(color: Color.homeSubtitle.opacity(0.5))
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
            }
            .font(AppFont.regularLabel(13))
            .foregroundColor(.homeSubtitle)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func sendEmail() {
        guard let email else { return }
        var parts = URLComponents()
        parts.queryItems = [
            URLQueryItem(name: "subject", value: HutMessage.subject(pod: pod)),
            URLQueryItem(name: "body", value: message)
        ]
        // `URLComponents` leaves "+" alone and turns spaces into %20; mailto wants %20.
        let query = parts.percentEncodedQuery ?? ""
        if let url = URL(string: "mailto:\(email)?\(query)") { openURL(url) }
    }

    private func call() {
        guard let phone, let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") else { return }
        copyMessage()   // so it can be read out or texted
        openURL(url)
    }

    private func openWebsite() {
        guard let website, let url = hutWebURL(website) else { return }
        openURL(url)
    }

    private func copyMessage() {
        UIPasteboard.general.string = message
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copied = false
        }
    }
}

/// The message Lenny writes: in French for a hut in France, else English.
enum HutMessage {
    static func subject(pod: Pod) -> String {
        pod.country == "France" ? "Demande de réservation" : "Booking request"
    }

    static func text(pod: Pod, guests: Int, arrival: Date, nights: Int) -> String {
        let french = pod.country == "France"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: french ? "fr_FR" : "en_GB")
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        let departure = Calendar.current.date(byAdding: .day, value: nights, to: arrival) ?? arrival
        let from = formatter.string(from: arrival)
        let to = formatter.string(from: departure)

        if french {
            return """
            Bonjour,

            Nous souhaiterions réserver \(guests) \(guests == 1 ? "place" : "places") au \(pod.name), du \(from) au \(to) (\(nights) \(nights == 1 ? "nuit" : "nuits")). Auriez-vous de la place à ces dates ?

            Merci d'avance, bien cordialement.
            """
        }
        return """
        Hello,

        We'd like to book \(guests) \(guests == 1 ? "bed" : "beds") at \(pod.name), from \(from) to \(to) (\(nights) \(nights == 1 ? "night" : "nights")). Do you have room on these dates?

        Thank you, kind regards.
        """
    }
}

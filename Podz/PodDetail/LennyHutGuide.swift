import SwiftUI

/// The sections of the extended pod detail, in reading order.
enum PodDetailSection: String, CaseIterable, Hashable {
    case about, onSite, goodToKnow, gettingThere, contact, source

    var title: String {
        switch self {
        case .about: return "About"
        case .onSite: return "On site"
        case .goodToKnow: return "Good to know"
        case .gettingThere: return "Getting there"
        case .contact: return "Contact"
        case .source: return "About this listing"
        }
    }

    /// The sections this pod has something to say in.
    static func available(for pod: Pod, photoCredit: String?) -> [PodDetailSection] {
        allCases.filter { section in
            switch section {
            case .about: return hutClean(pod.description) != nil
            case .onSite: return !(pod.facilities ?? []).isEmpty || !pod.isBookable
            case .goodToKnow: return true
            case .gettingThere: return pod.coordinate != nil
            case .contact: return !pod.contactLinks.isEmpty
            case .source: return !pod.isBookable || photoCredit != nil
            }
        }
    }
}

/// What Lenny says as you read down the page: a word on the section that's
/// on screen, from what the data says (rules on the device, like
/// `LennyTripTips`), and the one thing to do next. It never states what it
/// doesn't know: a gap becomes "ask the hut".
struct LennyHutGuide: View {
    let pod: Pod
    let liveBedsAvailable: Int?
    /// The section at the top of the page; `nil` before the first scroll.
    let section: PodDetailSection?
    let available: [PodDetailSection]
    var onGo: (PodDetailSection) -> Void
    var onWriteMessage: () -> Void

    /// Where the page is: before any scroll it's the first section, and Lenny
    /// opens with the overview.
    private var current: PodDetailSection { section ?? available.first ?? .goodToKnow }

    private var next: PodDetailSection? {
        guard let index = available.firstIndex(of: current), available.indices.contains(index + 1) else { return nil }
        return available[index + 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LennyReply(message: Self.message(for: section, pod: pod, liveBedsAvailable: liveBedsAvailable, first: available.first), mood: .idle)

            if let action {
                Button(action: action.run) {
                    HStack(spacing: 5) {
                        Text(action.title)
                            .font(AppFont.regularLabel(13))
                            .foregroundColor(.homeSubtitle)
                            .underline(color: Color.homeSubtitle.opacity(0.5))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.homeSubtitle)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Lined up with the bubble's text, past the avatar.
                .padding(.leading, 38)
            }
        }
        .animation(.smooth(duration: 0.3), value: section)
    }

    /// One thing to do from here: write to the hut where that's the way to
    /// book, else on to the next section.
    private var action: (title: String, run: () -> Void)? {
        if !pod.isBookable, pod.hasContact, current == .contact || next == nil {
            return ("Write the message", onWriteMessage)
        }
        if let next { return ("Next: \(next.title)", { onGo(next) }) }
        if let first = available.first, first != current { return ("Back to top", { onGo(first) }) }
        return nil
    }

    // MARK: - What Lenny says

    static func message(for section: PodDetailSection?, pod: Pod, liveBedsAvailable: Int?, first: PodDetailSection?, today: Date = Date()) -> String {
        switch section ?? first ?? .goodToKnow {
        case .about: return trust(pod, liveBedsAvailable)
        case .onSite: return onSite(pod)
        case .goodToKnow: return goodToKnow(pod, today)
        case .gettingThere:
            return "Tap the map for walking directions in Apple Maps. There's often no signal up there, so save the area offline before you leave."
        case .contact:
            if pod.isBookable { return "Happy with this hut? Tap Book and you're reserved in a minute." }
            return pod.hasContact
                ? "This is how to reach the hut. I can write the message for you, so you only have to send it."
                : "I have no way to reach this hut. Check it's open before you set off."
        case .source:
            return "OpenStreetMap is edited by volunteers, so details can be out of date. When it matters, ask the hut."
        }
    }

    /// Can you trust it, and what to do about it.
    private static func trust(_ pod: Pod, _ liveBedsAvailable: Int?) -> String {
        if pod.isBookable {
            guard let live = liveBedsAvailable else { return "This hut takes bookings right here in Podz. Scroll down and I'll walk you through it." }
            return live > 0
                ? "This hut takes bookings right here, and it has \(live) \(live == 1 ? "bed" : "beds") free tonight. Scroll down and I'll walk you through it."
                : "This hut takes bookings right here, but it's full tonight. Another date may work."
        }
        return pod.hasContact
            ? "I found this hut on OpenStreetMap and nobody at Podz has checked it, so I'd contact the hut before you go. I'll walk you through what we know."
            : "I found this hut on OpenStreetMap, but I have no way to reach it and nobody at Podz has checked it. I'll walk you through what we know."
    }

    private static func onSite(_ pod: Pod) -> String {
        guard let facilities = pod.facilities, !facilities.isEmpty else {
            return "No facilities are listed for this hut. Ask it what it offers (meals, water, a bed) before you count on it."
        }
        var text = "On site: \(list(facilities.filter { $0 != "Reservation required" }))."
        if !facilities.contains("Meals") { text += " I don't see meals listed, so bring food just in case." }
        if facilities.contains("Reservation required") { text += " It asks you to reserve first: don't walk up without a bed." }
        return text
    }

    private static func goodToKnow(_ pod: Pod, _ today: Date) -> String {
        var parts: [String] = []
        let month = Calendar(identifier: .gregorian).component(.month, from: today)
        if let hours = hutClean(pod.openingHours) {
            parts.append("It's open \(hours).")
        } else if !pod.isBookable {
            parts.append("Its opening dates aren't listed, so ask the hut.")
        }
        if let altitude = pod.altitudeM {
            if altitude >= 2000, [10, 11, 12, 1, 2, 3, 4, 5].contains(month) {
                parts.append("At \(altitude) m, huts are often closed or only have a winter room from October to May.")
            } else if altitude >= 2500 {
                parts.append("At \(altitude) m it gets cold, even in summer: pack a warm layer, a hat and a headlamp.")
            } else if altitude >= 1500 {
                parts.append("At \(altitude) m the evenings cool down fast.")
            }
        }
        return parts.isEmpty ? "Here's the practical side: where it is, how big it is and how you book." : parts.joined(separator: " ")
    }

    /// "Meals, Showers and Drinking water".
    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return "nothing listed"
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }
}

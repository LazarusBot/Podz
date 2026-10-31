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

/// Lenny's word on a hut, from what the data says (rules on the device). On the
/// stack it's the `LennyReply` bubble, one line of something useful that the
/// badges don't already say. On the extended page it's one compact line under
/// the header that follows the section on screen, with one move on the right
/// (the next section, or the hut's contact). It never states what it doesn't
/// know: a gap becomes "ask the hut".
struct LennyHutGuide: View {
    let pod: Pod
    let liveBedsAvailable: Int?
    /// The section at the top of the page; `nil` before the first scroll.
    var section: PodDetailSection?
    var available: [PodDetailSection] = []
    var onGo: (PodDetailSection) -> Void = { _ in }
    var onContact: () -> Void = {}
    /// The stack's bubble instead of the compact line.
    var inStack = false

    /// Where the page is: before any scroll it's the first section.
    private var current: PodDetailSection { section ?? available.first ?? .goodToKnow }

    private var next: PodDetailSection? {
        guard let index = available.firstIndex(of: current), available.indices.contains(index + 1) else { return nil }
        return available[index + 1]
    }

    var body: some View {
        if inStack {
            LennyReply(message: Self.stackMessage(pod, liveBedsAvailable), mood: .idle)
        } else {
            compact
        }
    }

    // MARK: - The compact line

    private var compact: some View {
        HStack(spacing: 10) {
            LennyMark(mood: .idle)
                .frame(width: 13, height: 13)
                .foregroundColor(.homeBackground)
                .frame(width: 26, height: 26)
                .background(Color.homeText, in: Circle())

            Text(Self.shortMessage(for: section, pod: pod, first: available.first))
                .font(AppFont.regularLabel(14))
                .foregroundColor(.homeText)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(current)
                .transition(.opacity)

            if let action {
                Button(action: action.run) {
                    HStack(spacing: 4) {
                        Text(action.title)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                    }
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background(Color.homePill, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .animation(.smooth(duration: 0.3), value: current)
    }

    /// One move from here: the hut's contact where that's the way to book, else
    /// on to the next section.
    private var action: (title: String, run: () -> Void)? {
        if !pod.isBookable, pod.hasContact, current == .contact || next == nil {
            return ("Contact", onContact)
        }
        if let next { return ("Next", { onGo(next) }) }
        if let first = available.first, first != current { return ("Top", { onGo(first) }) }
        return nil
    }

    // MARK: - What Lenny says

    /// On the stack: the one thing worth knowing that the badges above don't
    /// say. (Open or closed and "Unverified" are chips already.)
    private static func stackMessage(_ pod: Pod, _ liveBedsAvailable: Int?) -> String {
        if pod.isBookable {
            if let live = liveBedsAvailable {
                return live > 0
                    ? "\(live) \(live == 1 ? "bed" : "beds") free tonight. Tell me your dates and I'll book it."
                    : "Full tonight. Another date may work: tell me when and I'll check."
            }
            return "You can book this hut right here. Tell me your dates."
        }
        if let hours = hutClean(pod.openingHours) { return "Open \(hours). Call ahead, as huts fill up." }
        return pod.hasContact
            ? "This hut takes bookings itself. Tap Book through the hut to reach it."
            : "I have no way to reach this hut from here. Check it's open before you set off."
    }

    /// On the page: a short line for the section on screen (two lines at most).
    static func shortMessage(for section: PodDetailSection?, pod: Pod, first: PodDetailSection?) -> String {
        switch section ?? first ?? .goodToKnow {
        case .about:
            return pod.isBookable ? "Bookable right here in Podz." : "Details come from OpenStreetMap: confirm with the hut."
        case .onSite:
            guard let facilities = pod.facilities, !facilities.isEmpty else { return "Nothing listed: ask the hut what it offers." }
            let shown = facilities.filter { $0 != "Reservation required" }
            return facilities.contains("Reservation required") ? "Reserve first: it doesn't take walk-ups." : "On site: \(shown.prefix(3).joined(separator: ", "))."
        case .goodToKnow:
            if let altitude = pod.altitudeM, altitude >= 2500 { return "At \(altitude) m it's cold, even in summer: bring a warm layer." }
            return pod.isBookable ? "Pick your dates and Book." : "Opening dates and prices: ask the hut."
        case .gettingThere:
            return "Save the map offline: there's often no signal up there."
        case .contact:
            if pod.isBookable { return "Happy with it? Tap Book." }
            return pod.hasContact ? "Contact the hut to book a bed." : "No contact listed. Check it's open before you go."
        case .source:
            return "Volunteers edit OpenStreetMap, so details can be out of date."
        }
    }
}

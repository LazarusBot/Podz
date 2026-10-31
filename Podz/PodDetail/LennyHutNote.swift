import SwiftUI

/// Lenny's take on a hut, from what the data says (rules on the device, like
/// `LennyTripTips`). First what you can trust and what to do about it, then
/// the season, the altitude and what's on site. It never states what it
/// doesn't know: a gap becomes "ask the hut".
enum LennyHutTips {
    static func tips(for pod: Pod, liveBedsAvailable: Int?, today: Date = Date()) -> [String] {
        var tips: [String] = []

        // 1 - Can you trust it, and what to do.
        if pod.isBookable {
            if let live = liveBedsAvailable {
                tips.append(live > 0
                    ? "This hut takes bookings right here, and it has \(live) \(live == 1 ? "bed" : "beds") free tonight."
                    : "This hut takes bookings right here, but it's full tonight. Another date may work.")
            } else {
                tips.append("This hut takes bookings right here in Podz.")
            }
        } else if pod.hasContact {
            tips.append("I found this hut on OpenStreetMap and nobody at Podz has checked it. I'd contact the hut before you go. I can write the message for you.")
        } else {
            tips.append("I found this hut on OpenStreetMap, but I have no way to reach it and nobody at Podz has checked it. Double-check it's open before you set off.")
        }

        // 2 - When it's open.
        let month = Calendar(identifier: .gregorian).component(.month, from: today)
        if let hours = hutClean(pod.openingHours) {
            tips.append("It's open \(hours).")
        } else if !pod.isBookable {
            tips.append("Its opening dates aren't listed, so ask the hut.")
        }
        if let altitude = pod.altitudeM, altitude >= 2000, [10, 11, 12, 1, 2, 3, 4, 5].contains(month) {
            tips.append("Huts this high are often closed, or only have a winter room, from October to May. Check this one is open on your dates.")
        }

        // 3 - How high you'll sleep.
        if let altitude = pod.altitudeM {
            if altitude >= 2500 {
                tips.append("You'd sleep at \(altitude) m. It gets cold up there, even in summer, so pack a warm layer, a hat and a headlamp.")
            } else if altitude >= 1500 {
                tips.append("At \(altitude) m the evenings cool down fast. Keep a warm layer within reach.")
            }
        }

        // 4 - What's on site.
        if let facilities = pod.facilities, !facilities.isEmpty {
            tips.append("On site: \(list(facilities.filter { $0 != "Reservation required" })).")
            if !facilities.contains("Meals") {
                tips.append("I don't see meals listed, so bring food just in case.")
            }
            if facilities.contains("Reservation required") {
                tips.append("This hut asks you to reserve before you come. Don't walk up without a bed.")
            }
        }
        return tips
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

/// The note at the top of the sections: Lenny's bubble with one tip, and
/// "Another tip ›" to hear the next.
struct LennyHutNote: View {
    let tips: [String]

    @State private var index = 0

    var body: some View {
        if !tips.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                LennyReply(message: tips[index % tips.count], mood: .idle)

                if tips.count > 1 {
                    Button {
                        withAnimation(.smooth(duration: 0.3)) { index = (index + 1) % tips.count }
                    } label: {
                        HStack(spacing: 5) {
                            Text("Another tip")
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
        }
    }
}

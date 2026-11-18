import Foundation

/// What Lenny tells you about your next trip: a countdown, then tips that fit
/// where you're sleeping (how high, which season, how many of you). All from
/// the reservations and the pods, on the device.
enum LennyTripTips {
    /// One tip, as Lenny says it.
    struct Tip: Equatable {
        let text: String
    }

    static func tips(for trip: ReservationTrip, pods: [Pod], today: Date = Date()) -> [Tip] {
        let stayPods = trip.stays.compactMap { stay in pods.first { $0.id == stay.podId } }
        guard let start = Reservation.date(from: trip.checkIn) else { return [] }

        var tips: [Tip] = []

        // 1 - How soon, and what's booked.
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: today), to: start).day ?? 0
        let first = stayPods.first?.name
        let stays = trip.stays.count
        switch days {
        case ..<1:
            tips.append(Tip(text: "Your trip starts today. Have a great first night\(first.map { " at \($0)" } ?? "")!"))
        case 1:
            tips.append(Tip(text: "Your trip starts tomorrow. Time to pack!"))
        default:
            tips.append(Tip(text: "Your trip starts in \(days) days: \(stays) \(stays == 1 ? "stay" : "stays"), \(trip.nights) \(trip.nights == 1 ? "night" : "nights")\(first.map { ", beginning at \($0)" } ?? "")."))
        }

        // 1b - What the first hut says about itself (its hours, its phone): only
        // what it published, never anything Lenny made up.
        if let pod = stayPods.first, let hutTip = hutTip(for: pod) { tips.append(hutTip) }

        // 2 - How high you'll sleep.
        if let highest = stayPods.compactMap(\.altitudeM).max() {
            if highest >= 2500 {
                tips.append(Tip(text: "Your highest night is at \(highest) m. It gets cold up there, even in summer, so pack a warm layer, a hat and a headlamp."))
            } else if highest >= 1500 {
                tips.append(Tip(text: "You'll sleep as high as \(highest) m. Evenings cool down fast, so keep a warm layer within reach."))
            }
        }

        // 3 - The season, in the northern mountains.
        let month = Calendar(identifier: .gregorian).component(.month, from: start)
        if [11, 12, 1, 2, 3, 4].contains(month) {
            tips.append(Tip(text: "Snow can linger on the trails at this time of year. Check the conditions before each leg and start early."))
        } else if [6, 7, 8, 9].contains(month) {
            tips.append(Tip(text: "Afternoon storms are common in summer. Aim to reach each hut by early afternoon."))
        }

        // 4 - Huts and groups.
        tips.append(Tip(text: "Mountain huts serve dinner at a set time. If you'll be late, let them know. A sleeping bag liner and earplugs help too."))
        if stays > 1 {
            tips.append(Tip(text: "Between stops, check the weather the evening before and keep a margin in your day."))
        }
        if trip.guests >= 4 {
            tips.append(Tip(text: "With \(trip.guests) of you, pick one person to confirm arrival times with each hut."))
        }
        tips.append(Tip(text: "Tap a stay to see its hut again, and you can cancel the whole trip from here if plans change."))
        return tips
    }

    /// "Rifugio X: open June to September. If you'll be late, call +39 ...": what
    /// the hut itself gives (its opening hours and its phone), or nothing.
    private static func hutTip(for pod: Pod) -> Tip? {
        var parts: [String] = []
        if let status = OpeningStatus.evaluate(pod.openingHours) { parts.append("\(status.label).") }
        if let phone = pod.phone?.trimmingCharacters(in: .whitespaces), !phone.isEmpty {
            parts.append("If you'll be late, call \(phone).")
        }
        guard !parts.isEmpty else { return nil }
        return Tip(text: "\(pod.name): " + parts.joined(separator: " "))
    }
}

import Foundation

/// What Lenny tells you about your next trip: a countdown, then tips that fit
/// where you're sleeping (how high, which season, how many of you). All from
/// the reservations and the pods, on the device.
enum LennyTripTips {
    static func tips(for trip: ReservationTrip, pods: [Pod], today: Date = Date()) -> [String] {
        let stayPods = trip.stays.compactMap { stay in pods.first { $0.id == stay.podId } }
        guard let start = Reservation.date(from: trip.checkIn) else { return [] }

        var tips: [String] = []

        // 1 - How soon, and what's booked.
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: today), to: start).day ?? 0
        let first = stayPods.first?.name
        let stays = trip.stays.count
        switch days {
        case ..<1:
            tips.append("Your trip starts today. Have a great first night\(first.map { " at \($0)" } ?? "")!")
        case 1:
            tips.append("Your trip starts tomorrow. Time to pack!")
        default:
            tips.append("Your trip starts in \(days) days: \(stays) \(stays == 1 ? "stay" : "stays"), \(trip.nights) \(trip.nights == 1 ? "night" : "nights")\(first.map { ", beginning at \($0)" } ?? "").")
        }

        // 2 - How high you'll sleep.
        if let highest = stayPods.compactMap(\.altitudeM).max() {
            if highest >= 2500 {
                tips.append("Your highest night is at \(highest) m. It gets cold up there, even in summer, so pack a warm layer, a hat and a headlamp.")
            } else if highest >= 1500 {
                tips.append("You'll sleep as high as \(highest) m. Evenings cool down fast, so keep a warm layer within reach.")
            }
        }

        // 3 - The season, in the northern mountains.
        let month = Calendar(identifier: .gregorian).component(.month, from: start)
        if [11, 12, 1, 2, 3, 4].contains(month) {
            tips.append("Snow can linger on the trails at this time of year. Check the conditions before each leg and start early.")
        } else if [6, 7, 8, 9].contains(month) {
            tips.append("Afternoon storms are common in summer. Aim to reach each hut by early afternoon.")
        }

        // 4 - Huts and groups.
        tips.append("Mountain huts serve dinner at a set time. If you'll be late, let them know. A sleeping bag liner and earplugs help too.")
        if stays > 1 {
            tips.append("Between stops, check the weather the evening before and keep a margin in your day.")
        }
        if trip.guests >= 4 {
            tips.append("With \(trip.guests) of you, pick one person to confirm arrival times with each hut.")
        }
        tips.append("Tap a stay to see its pod again, and you can cancel the whole trip from here if plans change.")
        return tips
    }
}

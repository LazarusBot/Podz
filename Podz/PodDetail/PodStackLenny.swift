import SwiftUI

/// Lenny's word on the hut on the stack, or, while booking, the question: the
/// same bubble as in Lenny's search, just above the control stack. It is one of
/// four things: the booking's question, how a finished stay went, "did you book
/// it?" (back from a listed hut) or his one line on the hut.
struct PodStackLenny: View {
    let pod: Pod
    let liveBedsAvailable: Int?
    /// The line on the hut may be said (the zoom has settled, the beds are in).
    let guideReady: Bool
    let isBooking: Bool
    @ObservedObject var booking: BookingFlow
    let asksHowItWent: Bool
    @ObservedObject var feedback: StayFeedbackFlow
    let asksIfBooked: Bool
    /// "Not yet": Lenny's question is closed without an answer.
    var onNotYet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isBooking {
                LennyReply(message: booking.replyMessage, mood: booking.mood)
            } else if asksHowItWent {
                StayFeedbackLenny(flow: feedback, podName: pod.name)
                    .transition(.risesIn(after: 0.3))
            } else if asksIfBooked {
                // Back from the hut: the question rises into place a beat after
                // the photo has settled into its card.
                VStack(alignment: .leading, spacing: 8) {
                    LennyReply(message: "Welcome back! Did you book \(pod.name) with the hut?", mood: .happy)
                    Button(action: onNotYet) {
                        CaptionLabel("Not yet", vertical: 4, outset: 10)
                    }
                    .buttonStyle(.plain)
                    // Lined up with the bubble's text, past the avatar.
                    .padding(.leading, 38 + 18)
                }
                .transition(.asymmetric(
                    insertion: AnyTransition.move(edge: .bottom).combined(with: .opacity)
                        .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.3)),
                    removal: .opacity
                ))
            } else {
                LennyHutGuide(pod: pod, liveBedsAvailable: liveBedsAvailable, inStack: true, isPresent: guideReady)
            }
        }
    }
}

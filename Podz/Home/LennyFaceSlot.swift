import SwiftUI

/// Lenny's place beside a bubble. When several bubbles are on screen he sits
/// beside the one being said and glides down to the next when it arrives: give
/// every bubble a slot with the same `namespace`, and only the slot of the
/// current line has `isHere` (one face travels between them, so it is a move,
/// not a swap). `isShown` is his arrival (a pop), for the first bubble.
struct LennyFaceSlot: View {
    let isHere: Bool
    var isShown = true
    var mood: LennyMood = .idle
    let namespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isHere {
                LennyMark(mood: mood)
                    .foregroundColor(.homeBackground)
                    .background(Color.homeText, in: Circle())
                    .matchedGeometryEffect(id: "lenny", in: namespace)
                    .scaleEffect(isShown || reduceMotion ? 1 : 0.5)
                    .opacity(isShown ? 1 : 0)
                    .transition(.identity)
            }
        }
        .frame(width: 30, height: 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isShown)
        .accessibilityHidden(true)
    }
}

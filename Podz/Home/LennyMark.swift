import SwiftUI

/// How Lenny is doing, told by its face.
enum LennyMood: Equatable {
    /// Searching: a slow sway.
    case working
    /// Found something: a happy hop.
    case happy
    /// Couldn't: a shake of the head, "no".
    case sorry
}

/// Lenny's mark (the eyes and the mouth) with its moves. Size and color are
/// the caller's; the mood only moves it. Moves play once when the mood
/// changes; with Reduce Motion it stays still.
struct LennyMark: View {
    let mood: LennyMood

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Move {
        var rotation = 0.0
        var lift = 0.0
        var scale = 1.0
    }

    var body: some View {
        Image("lenny")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .phaseAnimator(mood == .working && !reduceMotion ? [-9.0, 9.0] : [0.0]) { view, angle in
                view.rotationEffect(.degrees(angle))
            } animation: { _ in .easeInOut(duration: 0.7) }
            .keyframeAnimator(initialValue: Move(), trigger: reduceMotion ? .working : mood) { view, move in
                view
                    .rotationEffect(.degrees(move.rotation))
                    .offset(y: move.lift)
                    .scaleEffect(move.scale)
            } keyframes: { _ in
                // The same tracks for every mood; a mood that doesn't use a
                // move just keeps its values at rest.
                let shake = mood == .sorry ? 1.0 : 0.0
                let hop = mood == .happy ? 1.0 : 0.0
                // A shake of the head, settling.
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(-16 * shake, duration: 0.11)
                    LinearKeyframe(14 * shake, duration: 0.14)
                    LinearKeyframe(-11 * shake, duration: 0.14)
                    LinearKeyframe(8 * shake, duration: 0.12)
                    LinearKeyframe(-4 * shake, duration: 0.1)
                    SpringKeyframe(0, duration: 0.2)
                }
                // A hop when happy, a small droop when sorry.
                KeyframeTrack(\.lift) {
                    SpringKeyframe(-7 * hop + 2 * shake, duration: 0.22)
                    SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1 + 0.2 * hop, duration: 0.22)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
            }
    }
}

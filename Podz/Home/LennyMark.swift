import SwiftUI

/// How Lenny is doing, told by its face.
enum LennyMood: Equatable {
    /// Searching: a slow sway.
    case working
    /// Found something: a happy hop.
    case happy
    /// Couldn't: a shake of the head, "no".
    case sorry
    /// Nothing to say: the face just rests.
    case idle
}

/// Lenny's face (two eyes, drawn at the size of his disc: size it like the disc) with its moves. Size and color are
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

/// Lenny's disc with his eyes **cut out of it**: they are holes, so they show
/// whatever is behind the disc (the ground in light or dark, a photo, a
/// bubble), never a color painted on. Size it like the disc. `color` is the
/// disc's; the eye parameters are for his intro (they come in, they blink).
struct LennyDisc: View {
    var mood: LennyMood = .idle
    var color: Color = .homeText
    /// 0...1: the eyes growing in from nothing.
    var eyesScale: CGFloat = 1
    /// 1 = open; a blink squashes it (never to a line).
    var eyesHeight: CGFloat = 1
    var eyesOpacity: Double = 1

    /// The middle of the eyes in the disc (see `Lenny.svg`).
    private let eyeCenter = UnitPoint(x: 0.5, y: 0.57)

    var body: some View {
        Circle()
            .fill(color)
            .mask {
                ZStack {
                    Rectangle()
                    LennyMark(mood: mood)
                        .scaleEffect(x: 1, y: eyesHeight, anchor: eyeCenter)
                        .scaleEffect(eyesScale, anchor: eyeCenter)
                        .opacity(eyesOpacity)
                        .foregroundColor(.black)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
    }
}

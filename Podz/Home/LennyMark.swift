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
        /// As a fraction of the face's height, so a hop is the same hop on a
        /// 26 pt avatar and on the intro's big disc.
        var lift = 0.0
        var scale = 1.0
    }

    /// How he looks once he couldn't find anything (the Figma "Error" frame): the
    /// eyes leant 11.4° to the right and sunk a little (5.3% of the disc down,
    /// 1.7% right). It is a resting pose, not a move, so it holds on a bubble
    /// that is sorry from its first frame too.
    private var isSorry: Bool { mood == .sorry }

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
                    .visualEffect { content, proxy in
                        content.offset(y: move.lift * proxy.size.height)
                    }
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
                // A light hop when happy (the eyes stay well inside the disc:
                // 8.5% of its height up, a swell of 8%).
                KeyframeTrack(\.lift) {
                    SpringKeyframe(-0.085 * hop, duration: 0.22)
                    SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1 + 0.08 * hop, duration: 0.22)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
            }
            // The error pose, on top of whatever move is playing.
            .rotationEffect(.degrees(isSorry ? 11.4 : 0))
            .visualEffect { content, proxy in
                content.offset(x: isSorry ? proxy.size.width * 0.017 : 0, y: isSorry ? proxy.size.height * 0.053 : 0)
            }
            .animation(.smooth(duration: 0.3), value: isSorry)
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
    var accessory: LennyAccessory? = nil

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
            .lennyAccessory(accessory)
    }
}

/// What Lenny wears when he speaks for a role (Figma "Host Lenny"). A hat or a
/// tie says **who is speaking or what kind of moment it is**, so each one means
/// one thing and appears rarely: the face never changes. They are drawn on top
/// of the disc and hang out of it, so use them from about 30 up (the details
/// are small below that). Fixed colors (not template): they read on both grounds.
enum LennyAccessory: Equatable {
    /// Hospitality, the hut's side of the stay: a red bellhop cap. Worn when the
    /// hut speaks (its own hours, its phone) and when a booking is confirmed.
    case bellhopCap
    /// A formal moment: a bow tie (drawn, not used yet).
    case bowTie

    fileprivate var asset: String {
        switch self {
        case .bellhopCap: "lennyCap"
        case .bowTie: "lennyTie"
        }
    }

    /// Size, the center's place (hundredths of the disc) and the tilt in degrees,
    /// read from the Figma frame (disc 100): the cap sits on top, tilted 3.5° to
    /// the left; the tie hangs below the chin, tilted 3.2°.
    fileprivate var geometry: (width: CGFloat, height: CGFloat, dx: CGFloat, dy: CGFloat, tilt: Double) {
        switch self {
        case .bellhopCap: (74, 49, -3.57, -43.3, -3.5)
        case .bowTie: (69.014, 67.791, 9.35, 75.72, -3.2)
        }
    }
}

private struct LennyAccessoryView: View {
    let accessory: LennyAccessory

    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)
            let g = accessory.geometry
            Image(accessory.asset)
                .renderingMode(.original)
                .resizable()
                .frame(width: g.width / 100 * d, height: g.height / 100 * d)
                .rotationEffect(.degrees(g.tilt))
                .position(x: d / 2 + g.dx / 100 * d, y: d / 2 + g.dy / 100 * d)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Puts an accessory on a Lenny disc (sized like the disc).
    @ViewBuilder
    func lennyAccessory(_ accessory: LennyAccessory?) -> some View {
        if let accessory {
            overlay { LennyAccessoryView(accessory: accessory) }
        } else {
            self
        }
    }
}

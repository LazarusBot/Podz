//
//  LennySearchAvatar.swift
//  Podz
//
//  Created by Max Prx on 13/09/2026.
//

import SwiftUI

/// The avatar shown in the plain (non-Lenny) search's empty state,
/// before a location's been typed (see `HomeView.awaitingQueryState`)
/// — Figma node 4549:1171 ("Avatar - Searching"). Same idea as
/// `LennyWalkingAvatar` (independently-moving pieces sharing one
/// `KeyframeAnimator` timeline, values straight from Figma's own
/// `get_motion_context`), but its own file/type rather than folded into
/// that one — a different node, different piece count and geometry,
/// and the two empty states can change independently.
///
/// Both legs reuse the exact same "Right Leg" artwork (Figma exports
/// them as two separate nodes, but downloaded identical) just rotated
/// to different resting angles and mirrored by position, not by a
/// flipped asset. Every piece here is centered within its own Figma
/// wrapper frame (`flex items-center justify-center`, no offset/
/// overflow trick), so rotation is just SwiftUI's own default
/// center-anchor — unlike `LennyWalkingAvatar`'s leg pivots, nothing
/// needs a separate "pivot box vs. art" split here.
struct LennySearchAvatar: View {
    private let canvasSize = CGSize(width: 193.786, height: 220.827)
    // Same shared target displayed *height* every empty-state
    // illustration in the app sizes itself to — see
    // `LennyWalkingAvatar.displayWidth`'s identical comment.
    var displayWidth: CGFloat = 135.6 / 220.827 * 193.786

    private var scale: CGFloat { displayWidth / canvasSize.width }

    private struct SearchValue {
        var bodyY: CGFloat = 0
        // Figma's own starting angles — both legs rest mid-swing, not
        // at 0, since the loop's first frame is already mid-motion.
        var rightLegDegrees: Double = -9.569
        var leftLegDegrees: Double = 25.726
        var glassDegrees: Double = -13.808
        var glassX: CGFloat = 0
        var glassY: CGFloat = 0
    }

    var body: some View {
        KeyframeAnimator(initialValue: SearchValue(), repeating: true) { value in
            ZStack(alignment: .topLeading) {
                Image("LennySearchBody")
                    .resizable()
                    .frame(width: 165, height: 165)
                    .offset(y: value.bodyY)

                piece(
                    imageName: "LennySearchLeg",
                    center: CGPoint(x: 121.66, y: 181.914),
                    size: CGSize(width: 44.069, height: 71.508),
                    rotationDegrees: value.rightLegDegrees
                )
                piece(
                    imageName: "LennySearchLeg",
                    center: CGPoint(x: 35.365, y: 178.774),
                    size: CGSize(width: 44.069, height: 71.508),
                    rotationDegrees: value.leftLegDegrees
                )
                // Magnifying glass: rotates in place *and* traces a
                // small loop around its resting center — Figma's own
                // "searching" sweep, not just a wobble.
                piece(
                    imageName: "LennySearchGlass",
                    center: CGPoint(x: 145.893 + value.glassX, y: 126.921 + value.glassY),
                    size: CGSize(width: 77, height: 88),
                    rotationDegrees: value.glassDegrees
                )
            }
            .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        } keyframes: { _ in
            KeyframeTrack(\.bodyY) {
                CubicKeyframe(-6, duration: 0.5)
                CubicKeyframe(0, duration: 0.5)
                CubicKeyframe(-6, duration: 0.5)
                CubicKeyframe(0, duration: 0.5)
            }
            KeyframeTrack(\.rightLegDegrees) {
                CubicKeyframe(-14.556, duration: 0.5)
                CubicKeyframe(-4.527, duration: 0.5)
                CubicKeyframe(-14.556, duration: 0.5)
                CubicKeyframe(-9.569, duration: 0.5)
            }
            KeyframeTrack(\.leftLegDegrees) {
                CubicKeyframe(30.713, duration: 0.5)
                CubicKeyframe(20.744, duration: 0.5)
                CubicKeyframe(30.713, duration: 0.5)
                CubicKeyframe(25.726, duration: 0.5)
            }
            KeyframeTrack(\.glassDegrees) {
                CubicKeyframe(-23.838, duration: 0.5)
                CubicKeyframe(-5.788, duration: 0.5)
                CubicKeyframe(-19.827, duration: 0.5)
                CubicKeyframe(-13.808, duration: 0.5)
            }
            KeyframeTrack(\.glassX) {
                CubicKeyframe(0.98, duration: 0.1)
                CubicKeyframe(3.983, duration: 0.1)
                CubicKeyframe(8.017, duration: 0.1)
                CubicKeyframe(11.02, duration: 0.1)
                CubicKeyframe(12, duration: 0.1)
                CubicKeyframe(10.367, duration: 0.1)
                CubicKeyframe(5.362, duration: 0.1)
                CubicKeyframe(-1.362, duration: 0.1)
                CubicKeyframe(-6.367, duration: 0.1)
                CubicKeyframe(-8, duration: 0.1)
                CubicKeyframe(-6.53, duration: 0.1)
                CubicKeyframe(-2.026, duration: 0.1)
                CubicKeyframe(4.026, duration: 0.1)
                CubicKeyframe(8.53, duration: 0.1)
                CubicKeyframe(10, duration: 0.1)
                CubicKeyframe(9.183, duration: 0.1)
                CubicKeyframe(6.681, duration: 0.1)
                CubicKeyframe(3.319, duration: 0.1)
                CubicKeyframe(0.817, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
            }
            KeyframeTrack(\.glassY) {
                CubicKeyframe(-1.697, duration: 0.1)
                CubicKeyframe(-6.216, duration: 0.1)
                CubicKeyframe(-9.591, duration: 0.1)
                CubicKeyframe(-9.564, duration: 0.1)
                CubicKeyframe(-5.901, duration: 0.1)
                CubicKeyframe(-0.099, duration: 0.1)
                CubicKeyframe(3.564, duration: 0.1)
                CubicKeyframe(3.707, duration: 0.1)
                CubicKeyframe(1.219, duration: 0.1)
                CubicKeyframe(-3.14, duration: 0.1)
                CubicKeyframe(-6.783, duration: 0.1)
                CubicKeyframe(-8, duration: 0.1)
                CubicKeyframe(-6.708, duration: 0.1)
                CubicKeyframe(-3, duration: 0.1)
                CubicKeyframe(0.708, duration: 0.1)
                CubicKeyframe(2, duration: 0.1)
                CubicKeyframe(1.742, duration: 0.1)
                CubicKeyframe(1, duration: 0.1)
                CubicKeyframe(0.258, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: displayWidth, height: canvasSize.height * scale, alignment: .topLeading)
    }

    /// Places `imageName` (its own natural `size`) centered at `center`
    /// (canvas coordinates) and rotates it around that same center —
    /// matching Figma's `flex items-center justify-center` wrapper +
    /// default-origin rotation exactly, without needing a separate
    /// wrapper frame.
    private func piece(imageName: String, center: CGPoint, size: CGSize, rotationDegrees: Double) -> some View {
        Image(imageName)
            .resizable()
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(rotationDegrees))
            .offset(x: center.x - size.width / 2, y: center.y - size.height / 2)
    }
}

#Preview {
    LennySearchAvatar()
        .padding(40)
}

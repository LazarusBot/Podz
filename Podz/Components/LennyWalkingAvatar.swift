//
//  LennyWalkingAvatar.swift
//  Podz
//
//  Created by Max Prx on 13/09/2026.
//

import SwiftUI

/// The hiker shown while Lenny is up but no query has been typed yet
/// (see `HomeView.awaitingLennyQueryState`) — Figma node 4533:4599
/// ("Walking Avatar"). Reproduced as five independently-moving pieces
/// (bag, body, two leg pivots, walking stick) rather than one flattened
/// image or `WobblingImage`'s whole-piece wobble — the real design is
/// an actual walk cycle (legs alternating opposite phase, the stick
/// tapping, body/bag bobbing slightly out of sync with each other), so
/// it needs one shared `KeyframeAnimator` driving all six tracks in
/// parallel to stay in sync.
///
/// Every position/size/keyframe value below comes straight from
/// Figma's own `get_design_context`/`get_motion_context` for this node
/// (an 850ms loop, each segment ease-in-out — `CubicKeyframe`'s own
/// default curve, so no explicit timing curve is passed anywhere here).
/// Positions are laid out at native canvas scale (183x224.667, this
/// node's own frame size) and scaled down together at the end, same
/// approach `PodsEmptyStateIllustration` uses.
struct LennyWalkingAvatar: View {
    private let canvasSize = CGSize(width: 183, height: 224.667)
    var displayWidth: CGFloat = 150

    private var scale: CGFloat { displayWidth / canvasSize.width }

    private struct WalkValue {
        var bagY: CGFloat = 0
        var bodyY: CGFloat = 0
        // Figma's own starting values (rad, converted to degrees) —
        // legs rest mid-swing, not at 0, since the loop's first frame
        // is already mid-stride.
        var leftLegDegrees: Double = -15.013
        var rightLegDegrees: Double = 15.013
        var stickDegrees: Double = -2.979
        // Not a delta from rest — Figma's own translate values are
        // never 0 (the stick's laid-out position, from its inset
        // below, is already offset by this much even at "rest").
        var stickY: CGFloat = 9
    }

    var body: some View {
        KeyframeAnimator(initialValue: WalkValue(), repeating: true) { value in
            ZStack(alignment: .topLeading) {
                // Bag: Figma exports this as a rotated node, so its own
                // wrapper is the ~91x125 axis-aligned bounding box of a
                // 124.585x91.0716 rectangle turned -90.15° — simpler to
                // just rotate the natural-size art directly and offset
                // it so its (pre-rotation) frame center lands on that
                // bounding box's own center (26.7, 73.41 in canvas
                // space) instead of reconstructing the AABB math.
                Image("LennyWalkerBag")
                    .resizable()
                    .frame(width: 124.585, height: 91.0716)
                    .rotationEffect(.degrees(-90.15))
                    .offset(x: -35.59, y: 27.88 + value.bagY)

                Image("LennyWalkerBody")
                    .resizable()
                    .frame(width: 165, height: 165)
                    .offset(y: value.bodyY)

                // Each leg's actual artwork is larger than its own
                // "pivot" frame (Figma overflows it past one edge) —
                // the frame is what rotates, sized/positioned so its
                // *center* is the hip joint; the art is offset within
                // it, exactly matching the CSS this was exported as
                // (rotate the frame at its default center origin, let
                // the oversized art bleed past the frame's own edges).
                legPivot(
                    imageName: "LennyWalkerLeftLeg",
                    pivotOrigin: CGPoint(x: 14.81, y: 64.49),
                    pivotSize: CGSize(width: 64.069, height: 143.015),
                    artOffset: CGPoint(x: -13.288, y: 0),
                    artSize: CGSize(width: 77.3548, height: 152.956),
                    rotationDegrees: value.leftLegDegrees
                )
                legPivot(
                    imageName: "LennyWalkerRightLeg",
                    pivotOrigin: CGPoint(x: 77.38, y: 82.64),
                    pivotSize: CGSize(width: 64.069, height: 143.015),
                    artOffset: .zero,
                    artSize: CGSize(width: 65.1591, height: 143.015),
                    rotationDegrees: value.rightLegDegrees
                )

                // Stick: its own asset already matches its laid-out
                // frame size almost exactly, so no separate pivot
                // frame/art-offset split is needed here — just rotate
                // and translate the image directly, same as the CSS.
                Image("LennyWalkerStick")
                    .resizable()
                    .frame(width: 8, height: 150)
                    .rotationEffect(.degrees(value.stickDegrees))
                    .offset(x: 170.01 + 10, y: 55 + value.stickY)
            }
            .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        } keyframes: { _ in
            KeyframeTrack(\.bagY) {
                CubicKeyframe(-4, duration: 0.15)
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(2, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(-4, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(2, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
            }
            KeyframeTrack(\.bodyY) {
                CubicKeyframe(-4, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(2, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(-4, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(2, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(0, duration: 0.05)
            }
            KeyframeTrack(\.leftLegDegrees) {
                CubicKeyframe(0, duration: 0.2)
                CubicKeyframe(15.013, duration: 0.2)
                CubicKeyframe(0, duration: 0.2)
                CubicKeyframe(-15.013, duration: 0.2)
                CubicKeyframe(-15.013, duration: 0.05)
            }
            KeyframeTrack(\.rightLegDegrees) {
                CubicKeyframe(0, duration: 0.2)
                CubicKeyframe(-15.013, duration: 0.2)
                CubicKeyframe(0, duration: 0.2)
                CubicKeyframe(15.013, duration: 0.2)
                CubicKeyframe(15.013, duration: 0.05)
            }
            KeyframeTrack(\.stickDegrees) {
                CubicKeyframe(0, duration: 0.2)
                CubicKeyframe(2.979, duration: 0.2)
                CubicKeyframe(0, duration: 0.2)
                CubicKeyframe(-2.979, duration: 0.2)
                CubicKeyframe(-2.979, duration: 0.05)
            }
            KeyframeTrack(\.stickY) {
                CubicKeyframe(12, duration: 0.1)
                CubicKeyframe(15, duration: 0.1)
                CubicKeyframe(12, duration: 0.1)
                CubicKeyframe(9, duration: 0.1)
                CubicKeyframe(12, duration: 0.1)
                CubicKeyframe(15, duration: 0.1)
                CubicKeyframe(12, duration: 0.1)
                CubicKeyframe(9, duration: 0.1)
                CubicKeyframe(9, duration: 0.05)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        // See `PodsEmptyStateIllustration`'s own identical trailing
        // `.frame` for why this second frame (not just `scaleEffect`)
        // is needed — `scaleEffect` doesn't shrink what the view
        // reports as its own size.
        .frame(width: displayWidth, height: canvasSize.height * scale, alignment: .topLeading)
    }

    private func legPivot(
        imageName: String,
        pivotOrigin: CGPoint,
        pivotSize: CGSize,
        artOffset: CGPoint,
        artSize: CGSize,
        rotationDegrees: Double
    ) -> some View {
        Image(imageName)
            .resizable()
            .frame(width: artSize.width, height: artSize.height)
            .offset(x: artOffset.x, y: artOffset.y)
            .frame(width: pivotSize.width, height: pivotSize.height, alignment: .topLeading)
            .rotationEffect(.degrees(rotationDegrees))
            .offset(x: pivotOrigin.x, y: pivotOrigin.y)
    }
}

#Preview {
    LennyWalkingAvatar()
        .padding(40)
}

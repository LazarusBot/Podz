//
//  WobblingImage.swift
//  Podz
//
//  Created by Max Prx on 12/09/2026.
//

import SwiftUI

/// An image that idles with a small rotational wobble plus a vertical
/// bounce, looping forever — the exact shape of motion Figma's own Smart
/// Animate exports for a micro-interaction like this: a lead-in hold at
/// rest, N alternating legs, then a trail-out back to rest, not a plain
/// sine-like oscillation. `KeyframeAnimator` mirrors that timeline
/// directly (see `PodsView`'s empty-state illustration, built from the
/// exact keyframe percentages/values Figma's `get_motion_context`
/// returned for each of its three pieces) rather than approximating it
/// with a single repeating `withAnimation`, since the real export has
/// more turns and an uneven lead-in/trail-out than a bare back-and-forth
/// would give.
///
/// All durations are in seconds and should sum to the same total per
/// track (rotation and bounce) so both loop back to rest together.
struct WobblingImage: View {
    let imageName: String
    let size: CGSize

    /// Degrees the image tips to on each side of rest. Rotation
    /// alternates strictly between -amplitude and +amplitude (never
    /// resting at 0 mid-swing) — only the lead-in/trail-out keyframes
    /// are ever exactly 0.
    var rotationAmplitude: Double
    var rotationLegCount: Int
    var rotationLegSeconds: Double
    var rotationLeadInSeconds: Double
    var rotationTrailOutSeconds: Double

    /// Points the image bounces upward (negative Y) on each leg,
    /// alternating between -amplitude and rest (0) — a bounce, not a
    /// side-to-side swing.
    var bounceAmplitude: CGFloat
    var bounceLegCount: Int
    var bounceLegSeconds: Double
    var bounceLeadInSeconds: Double
    var bounceTrailOutSeconds: Double

    private struct WobbleValue {
        var rotation: Double = 0
        var offsetY: CGFloat = 0
    }

    var body: some View {
        KeyframeAnimator(initialValue: WobbleValue(), repeating: true) { value in
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .rotationEffect(.degrees(value.rotation))
                .offset(y: value.offsetY)
        } keyframes: { _ in
            KeyframeTrack(\.rotation) {
                CubicKeyframe(0, duration: rotationLeadInSeconds)
                for leg in 0..<rotationLegCount {
                    CubicKeyframe(
                        leg.isMultiple(of: 2) ? -rotationAmplitude : rotationAmplitude,
                        duration: rotationLegSeconds
                    )
                }
                CubicKeyframe(0, duration: rotationTrailOutSeconds)
            }
            KeyframeTrack(\.offsetY) {
                CubicKeyframe(0, duration: bounceLeadInSeconds)
                for leg in 0..<bounceLegCount {
                    CubicKeyframe(
                        leg.isMultiple(of: 2) ? -bounceAmplitude : 0,
                        duration: bounceLegSeconds
                    )
                }
                CubicKeyframe(0, duration: bounceTrailOutSeconds)
            }
        }
    }
}

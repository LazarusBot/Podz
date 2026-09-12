//
//  HeartbeatImage.swift
//  Podz
//
//  Created by Max Prx on 12/09/2026.
//

import SwiftUI

/// An image that idles with periodic "heartbeat" pulses — a quick
/// rotate+scale+bounce, then a rest, repeated `beatCount` times per loop —
/// rather than `WobblingImage`'s continuous back-and-forth. Matches the
/// shape of motion Figma's own `get_motion_context` returned for
/// LikesView's small broken-heart accents (node 4512:392): each one beats
/// on its own period with a small phase offset from the others, via
/// `initialDelaySeconds`, so the three don't beat in lockstep.
///
/// Simplified from the exact keyframe export (which used 4-5 uneven
/// percentages per beat) down to one evenly-stepped 3-point pulse per
/// property — close enough for a decorative micro-interaction, and much
/// easier to tune than hand-porting every odd percentage.
struct HeartbeatImage: View {
    let imageName: String
    let size: CGSize

    var rotationAmplitudeDegrees: Double
    var bounceAmplitude: CGFloat
    var scaleUp: CGFloat
    var scaleDown: CGFloat

    var beatCount: Int = 3
    var activeSeconds: Double = 1.6
    var restSeconds: Double = 0.8
    var initialDelaySeconds: Double = 0

    private struct BeatValue {
        var rotation: Double = 0
        var offsetY: CGFloat = 0
        var scale: CGFloat = 1
    }

    /// Flattened to one (value, duration) pair per list entry, looped with
    /// exactly one `CubicKeyframe` per iteration — a `KeyframeTrack`'s
    /// result builder can't reliably infer its opaque content type when a
    /// single loop iteration emits more than one keyframe, so the 4
    /// keyframes-per-beat shape has to be built as data first, not written
    /// directly as repeated statements inside the loop.
    private func keyframePairs<T>(rest: T, beat: [T]) -> [(T, Double)] {
        var pairs: [(T, Double)] = [(rest, initialDelaySeconds)]
        let step = activeSeconds / Double(beat.count)
        for _ in 0..<beatCount {
            for value in beat {
                pairs.append((value, step))
            }
            pairs.append((rest, restSeconds))
        }
        return pairs
    }

    var body: some View {
        KeyframeAnimator(initialValue: BeatValue(), repeating: true) { value in
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .scaleEffect(value.scale)
                .rotationEffect(.degrees(value.rotation))
                .offset(y: value.offsetY)
        } keyframes: { _ in
            KeyframeTrack(\.rotation) {
                for (value, duration) in keyframePairs(rest: 0, beat: [rotationAmplitudeDegrees, -rotationAmplitudeDegrees, 0]) {
                    CubicKeyframe(value, duration: duration)
                }
            }
            KeyframeTrack(\.offsetY) {
                for (value, duration) in keyframePairs(rest: 0, beat: [-bounceAmplitude, bounceAmplitude * 0.15, 0]) {
                    CubicKeyframe(value, duration: duration)
                }
            }
            KeyframeTrack(\.scale) {
                for (value, duration) in keyframePairs(rest: 1, beat: [scaleUp, scaleDown, 1]) {
                    CubicKeyframe(value, duration: duration)
                }
            }
        }
    }
}

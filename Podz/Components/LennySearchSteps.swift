//
//  LennySearchSteps.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import SwiftUI

/// The 3-step progress list under the search bar while Lenny works —
/// Figma node 3796:690 (dots: 3802:825/829/840, step text: 3806:878,
/// 3802:850/854). Every dimension below is that node's own pixel
/// values scaled up by `scale` — proportions/colors match exactly,
/// just sized up a notch from Figma's own tiny 10/8pt mobile spec so
/// it reads as a real feature instead of fine print.
struct LennySearchSteps: View {
    let steps: [LennySearchViewModel.StepInfo]

    /// Uniform scale-up over Figma's own 1x values — keeps every
    /// dimension proportional to the reference (dot size, connector
    /// length, gaps, type) rather than hand-tuning each one separately.
    private let scale: CGFloat = 1.4

    private var dotDiameter: CGFloat { 12 * scale }
    private var innerDotDiameter: CGFloat { 8 * scale }
    /// Figma's own segment-1 dash ("M6 12V70", `#EEEEEE`, `2 2` dash) —
    /// the only segment that actually connects one real dot to the
    /// next; its other two (fading further down) exist there only to
    /// trail off past a 4th/5th step neither of our screens ever has.
    private var connectorHeight: CGFloat { 58 * scale }
    private var dotColumnToTextGap: CGFloat { 7 * scale }
    private var titleSubtitleGap: CGFloat { 4 * scale }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: dotColumnToTextGap) {
                    VStack(spacing: 0) {
                        StepDot(isDone: step.isDone, diameter: dotDiameter, innerDiameter: innerDotDiameter)
                        if index < steps.count - 1 {
                            DashedConnector()
                                .frame(width: 1, height: connectorHeight)
                        }
                    }
                    .animation(.easeOut(duration: 0.3), value: step.isDone)

                    VStack(alignment: .leading, spacing: titleSubtitleGap) {
                        Text(step.title)
                            .font(.system(size: 10 * scale, weight: .bold))
                            .foregroundColor(step.isDone ? .black : .appTextMuted.opacity(0.5))
                        if !step.subtitle.isEmpty {
                            Text(step.subtitle)
                                .font(.system(size: 8 * scale, weight: .medium))
                                .foregroundColor(step.isDone ? .appTextMuted : .appTextMuted.opacity(0.5))
                        }
                    }
                    .animation(.easeOut(duration: 0.3), value: step.isDone)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
}

/// A step's own dot (Figma's `Ellipse 7`/`Ellipse 8`): a soft radial
/// halo filling the full dot box, with a smaller solid circle centered
/// on top — black when done, `#CCCCCC` (not a hollow/stroked ring)
/// while still pending. The halo itself doesn't change with state —
/// Figma's own pending dot (node 3802:840) uses the identical gradient,
/// just a lighter inner fill.
private struct StepDot: View {
    let isDone: Bool
    let diameter: CGFloat
    let innerDiameter: CGFloat

    private static let haloGradient = Gradient(colors: [
        Color(red: 0xAA / 255, green: 0xAA / 255, blue: 0xAA / 255),
        Color(red: 0xE1 / 255, green: 0xE1 / 255, blue: 0xE1 / 255)
    ])
    private static let pendingFill = Color(red: 0xCC / 255, green: 0xCC / 255, blue: 0xCC / 255)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(gradient: Self.haloGradient, center: .center, startRadius: 0, endRadius: diameter / 2))
                .opacity(0.2)
                .frame(width: diameter, height: diameter)
            Circle()
                .fill(isDone ? Color.black : Self.pendingFill)
                .frame(width: innerDiameter, height: innerDiameter)
        }
    }
}

/// The dashed line connecting one step's dot to the next — Figma's own
/// `#EEEEEE`, `2 2` dash (scaled up with everything else). Reads its
/// actual height from the `.frame` the call site gives it (a plain
/// `Path` has no size of its own to draw a full-height line against
/// otherwise).
private struct DashedConnector: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: proxy.size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height))
            }
            .stroke(
                Color(red: 0xEE / 255, green: 0xEE / 255, blue: 0xEE / 255),
                style: StrokeStyle(lineWidth: 1.5, dash: [2.8, 2.8])
            )
        }
    }
}

#Preview {
    LennySearchSteps(steps: [
        .init(id: 0, title: "Extracting three stops", subtitle: "Three Peaks, Lake Braies, and Lake Sorapis", isDone: true),
        .init(id: 1, title: "Finding the best podz around this point", subtitle: "Dolomiti, Italian Alps", isDone: true),
        .init(id: 2, title: "Loading your itinerary...", subtitle: "Can take up to 2 minutes", isDone: false)
    ])
}

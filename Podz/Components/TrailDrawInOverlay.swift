//
//  TrailDrawInOverlay.swift
//  Podz
//
//  Created by Max Prx on 09/09/2026.
//

import SwiftUI

/// A decorative trail line that draws itself in over `PodDetailView`'s
/// static map — the same "self-drawing route" flourish Strava plays on its
/// own activity maps. Podz has no real trail geometry to animate, so this
/// is one stylized switchback path in unit-square space, not tied to any
/// actual coordinates — meant to read as "here's the way in," never as a
/// literal recorded route.
///
/// Purely decorative: `.allowsHitTesting(false)` and hidden from
/// accessibility, so it never competes with the map's own "Open in Maps"
/// tap target or accessibility label.
struct TrailDrawInOverlay: View {
    @State private var progress: CGFloat = 0

    private static let trailheadUnitPoint = (x: 0.16, y: 0.92)

    private func path(in size: CGSize) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * size.width, y: y * size.height)
        }
        var path = Path()
        path.move(to: point(Self.trailheadUnitPoint.x, Self.trailheadUnitPoint.y))
        path.addCurve(
            to: point(0.62, 0.66),
            control1: point(0.22, 0.7),
            control2: point(0.4, 0.78)
        )
        path.addCurve(
            to: point(0.4, 0.4),
            control1: point(0.78, 0.58),
            control2: point(0.52, 0.52)
        )
        path.addCurve(
            to: point(0.66, 0.16),
            control1: point(0.3, 0.3),
            control2: point(0.5, 0.24)
        )
        return path
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                path(in: geometry.size)
                    .trim(from: 0, to: progress)
                    .stroke(Color.appAccentBlack, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

                // Trailhead marker — same small dot-with-white-ring
                // treatment as a map "you are here," faded in alongside
                // the line rather than present from the start, so it
                // reads as part of the same reveal.
                Circle()
                    .fill(Color.appAvailableGreen)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .position(
                        x: Self.trailheadUnitPoint.x * geometry.size.width,
                        y: Self.trailheadUnitPoint.y * geometry.size.height
                    )
                    .opacity(progress > 0 ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            // A beat after the map's own camera has settled, not
            // simultaneous with it — reads as its own "here's the way
            // in" moment rather than noise competing with the map still
            // loading in.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 1.3)) {
                    progress = 1
                }
            }
        }
    }
}

#Preview {
    TrailDrawInOverlay()
        .frame(height: 283)
        .background(Color.gray.opacity(0.2))
}

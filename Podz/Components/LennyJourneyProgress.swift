//
//  LennyJourneyProgress.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import SwiftUI

/// Horizontal timeline of stops (node 3829:2003/2019) — a filled dot for
/// each resolved stop with its pod count, connected by dashed lines to
/// still-pending stops shown grayed out.
struct LennyJourneyProgress: View {
    let stops: [LennySearchViewModel.JourneyStop]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    dot(resolved: stop.isResolved)
                    if index < stops.count - 1 {
                        dashedLine(resolved: stop.isResolved)
                    }
                }
            }

            HStack(alignment: .top, spacing: 24) {
                ForEach(stops) { stop in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stop.isResolved ? stop.name : "-")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(stop.isResolved ? .appTextPrimary : .appJourneyUnresolvedIcon)
                        Text("\(stop.podsFound) pods found matching your needs")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(stop.isResolved ? .appTextMuted : .appJourneyUnresolvedIcon)
                    }
                    .frame(width: 100, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private func dot(resolved: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(resolved ? Color.red : Color.appJourneyUnresolvedRing, lineWidth: 1.5)
                .frame(width: 12, height: 12)
            if resolved {
                Circle().fill(Color.red).frame(width: 8, height: 8)
            }
        }
    }

    private func dashedLine(resolved: Bool) -> some View {
        Rectangle()
            .fill(resolved ? Color.red.opacity(0.4) : Color.appJourneyUnresolvedRing)
            .frame(height: 1)
            .overlay(
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundColor(resolved ? Color.red.opacity(0.4) : Color.appJourneyUnresolvedRing)
            )
            .frame(maxWidth: .infinity)
    }
}

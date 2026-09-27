//
//  LikesPodCard.swift
//  Podz
//
//  Created by Max Prx on 27/09/2026.
//

import SwiftUI

/// A liked pod, sized for a two-column grid — replaces `LennyResultCard`'s
/// wide single-column row inside a folder's contents. Square photo on top
/// (same corner treatment as `PodCard`'s own thumbnails elsewhere in the
/// app), a richer caption underneath than `PodCard`'s bare name: name plus
/// region/country, so a folder full of pods actually reads as a place list,
/// not just a wall of photos.
struct LikesPodCard: View {
    let pod: Pod
    let photoURL: String?
    /// `nil` hides the unlike button entirely — used for a folder shared
    /// with you, where removing someone else's like isn't a real action
    /// (a heart that quietly does nothing is worse than no heart at all).
    var onUnlike: (() -> Void)? = nil
    var onTap: () -> Void

    var body: some View {
        // `.onTapGesture` on the outer container, not a `Button` — same
        // reasoning as `PodCard`'s identical structure: the unlike button
        // below is a real nested `Button`, and an outer `Button` around
        // it too is exactly the nested-Button-hit-testing ambiguity that
        // pattern avoids.
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                PodPhoto(url: photoURL)
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.r18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.r18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.75), lineWidth: 3)
                    )

                if let onUnlike {
                    Button(action: onUnlike) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(9)
                            .background(Circle().fill(Color.black.opacity(0.35)))
                            .contentShape(Rectangle())
                    }
                    .padding(6)
                    .accessibilityLabel("Unlike")
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(pod.name)
                    .font(AppFont.pillLabelSemiBold(16))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let region = pod.region {
                        Text(region)
                        Circle().fill(Color.appTextMuted).frame(width: 3, height: 3)
                    }
                    Text(pod.country)
                }
                .font(AppFont.regularLabel(12))
                .foregroundColor(.appTextMuted)
                .lineLimit(1)
            }
            .padding(.leading, 5)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

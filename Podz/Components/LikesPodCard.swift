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
    /// Explicit, not `.aspectRatio(1, contentMode: .fill)` on its own — an
    /// aspect ratio with no preceding fixed frame sizes itself against
    /// whatever height the grid row happens to propose (effectively
    /// unbounded, since `LazyVGrid` rows size to content), not the column
    /// width the grid actually gave it, and blew up well past the second
    /// column. Same fix `PodCard` already uses for the identical problem:
    /// the caller measures real available width and hands down a size.
    let size: CGFloat
    /// `nil` hides the unlike button entirely — used for a folder shared
    /// with you, where removing someone else's like isn't a real action
    /// (a heart that quietly does nothing is worse than no heart at all).
    var onUnlike: (() -> Void)? = nil
    var onTap: () -> Void
    /// Source side of the zoom transition into `PodDetailView`.
    var zoomNamespace: Namespace.ID? = nil

    /// Caption scales down with a narrower card the same way `PodCard`'s
    /// own text does — 160 is that card's own baseline size.
    private var scale: CGFloat { size / 160 }

    var body: some View {
        // `.onTapGesture` on the outer container, not a `Button` — same
        // reasoning as `PodCard`'s identical structure: the unlike button
        // below is a real nested `Button`, and an outer `Button` around
        // it too is exactly the nested-Button-hit-testing ambiguity that
        // pattern avoids.
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                PodPhoto(url: photoURL)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.r18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.r18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.75), lineWidth: 3)
                    )
                    .podZoomSource(id: pod.id, in: zoomNamespace, cornerRadius: AppRadius.r18)

                // Exactly `PodCard`'s own like-button styling (same
                // component, `showLikeButton`'s branch) — no background
                // circle, red glyph directly on the photo — so the heart
                // reads as the same control wherever it shows up in the
                // app, not a different one that happens to mean the same
                // thing.
                if let onUnlike {
                    Button(action: onUnlike) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(11)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Unlike")
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(pod.name)
                    .font(AppFont.pillLabelSemiBold(16 * scale))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let region = pod.region {
                        Text(region)
                        Circle().fill(Color.appTextMuted).frame(width: 3, height: 3)
                    }
                    Text(pod.country)
                }
                .font(AppFont.regularLabel(12 * scale))
                .foregroundColor(.appTextMuted)
                .lineLimit(1)
            }
            .padding(.leading, 5)
        }
        .frame(width: size, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

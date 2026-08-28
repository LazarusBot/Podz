//
//  PostCard.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import SwiftUI

/// One friend's post about a pod — author + pod + time, a photo strip,
/// the text body, then like/comment actions with an inline comment
/// thread.
struct PostCard: View {
    let post: Post
    /// Passed down from HomeView's own measured section width (same
    /// pattern as PodSection → PodCard's `size`) — applied as a hard
    /// `.frame(width:)` below, not just a max, so nothing inside the card
    /// (a bad aspect-ratio computation, a fanned photo stack, anything)
    /// can ever push it wider than its actual place in the feed.
    var cardWidth: CGFloat
    var onTapPod: (() -> Void)? = nil

    @ObservedObject private var postsStore = PostsStore.shared
    @ObservedObject private var podsStore = PodsStore.shared
    @State private var isCommentsExpanded = false
    @State private var commentDraft = ""
    /// Which photo is currently the big "hero" when there's more than
    /// one — tapping a small stacked thumbnail promotes it here instead.
    @State private var selectedPhotoIndex = 0

    private var author: Profile? { postsStore.profile(for: post.authorId) }
    private var pod: Pod? { podsStore.pods.first { $0.id == post.podId } }
    private var photos: [PostPhoto] { postsStore.photos(for: post.id) }
    private var comments: [PostComment] { postsStore.comments(for: post.id) }
    /// The one concrete number every photo element sizes itself to —
    /// `cardWidth` minus the card's own 16pt padding on each side. Every
    /// photo view below uses this exact value instead of a flexible
    /// `maxWidth: .infinity`, so there's a single source of truth for
    /// "how wide is this card's content" instead of several independent
    /// layout computations that could each resolve slightly differently.
    private var contentWidth: CGFloat { cardWidth - 32 }
    /// One fixed height for every photo, single or hero alike — no
    /// aspect-ratio math, no expand/collapse, no per-photo variation.
    /// `.fill` just crops whatever comes in to this same box every time.
    private let photoHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !photos.isEmpty {
                photoStrip
            }

            if let body = post.body, !body.isEmpty {
                Text(body)
                    .font(AppFont.mediumLabel(14))
                    .foregroundColor(.black)
            }

            actionRow

            if isCommentsExpanded {
                commentsSection
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.appFieldBg)
                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Color.appBorder, lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .frame(width: cardWidth, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            AvatarView(imageName: author?.avatarURL, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(author?.displayName ?? "Someone")
                    .font(AppFont.pillLabelBold(15))
                    .foregroundColor(.black)
                HStack(spacing: 4) {
                    if let pod {
                        Text(pod.name)
                            .font(AppFont.mediumLabel(12))
                            .foregroundColor(.appTextMuted)
                        Text("·")
                            .font(AppFont.mediumLabel(12))
                            .foregroundColor(.appTextMuted)
                    }
                    Text(Self.relativeTime(post.createdAt))
                        .font(AppFont.mediumLabel(12))
                        .foregroundColor(.appTextMuted)
                }
            }
            Spacer()

            // A dedicated button, not a tap-anywhere-on-the-header gesture
            // — the header also contains the author's own name/avatar,
            // and a single "go to the pod" affordance reads clearer as
            // its own explicit control than an implicit whole-row tap.
            // Bare glyph, no circle/background — same gray as every other
            // disabled-looking control in the app (see PostComposerView's
            // disabled Post button), since this is a quiet secondary
            // action next to the post's own content, not a primary one.
            Button(action: { onTapPod?() }) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appBorder)
            }
        }
    }

    /// One fixed `contentWidth` × `photoHeight` box for every photo —
    /// single photo or hero alike, `.fill` cropped — no aspect-ratio math
    /// and nothing that changes size on tap. Multiple photos: Figma's
    /// "Frame 71", the rest fanned in a small stack over the hero's
    /// bottom-trailing corner; tapping a stacked thumbnail swaps it into
    /// the (still identically sized) hero slot.
    @ViewBuilder
    private var photoStrip: some View {
        if photos.count == 1, let photo = photos.first {
            PodPhoto(url: photo.url, contentMode: .fill)
                .frame(width: contentWidth, height: photoHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ZStack(alignment: .bottomTrailing) {
                heroPhoto
                photoStack
            }
            // A passive "1/3" readout, always there regardless of
            // interaction — the fanned stack already hints at more
            // photos, but shouldn't be the *only* way to notice them.
            .overlay(alignment: .topLeading) {
                Text("\(safeSelectedIndex + 1)/\(photos.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .padding(10)
            }
        }
    }

    private var heroPhoto: some View {
        PodPhoto(url: photos[safeSelectedIndex].url, contentMode: .fill)
            .frame(width: contentWidth, height: photoHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Clamped so a stale index (shouldn't happen — `photos` doesn't
    /// shrink post-load — but cheap insurance against an index crash)
    /// never reads out of bounds.
    private var safeSelectedIndex: Int {
        min(selectedPhotoIndex, photos.count - 1)
    }

    /// Up to 3 of the *other* photos, fanned over the hero's bottom-
    /// trailing corner (Figma's "Frame 71") — the last one shows a "+N"
    /// badge for whatever doesn't fit. Tapping any of them promotes it to
    /// the hero; the hero it replaces rejoins this stack.
    private var photoStack: some View {
        let otherIndices = photos.indices.filter { $0 != safeSelectedIndex }
        let visible = Array(otherIndices.prefix(3))
        let overflow = otherIndices.count - visible.count

        return ZStack(alignment: .bottomTrailing) {
            ForEach(Array(visible.enumerated()), id: \.offset) { position, photoIndex in
                let distanceFromFront = visible.count - 1 - position
                PodPhoto(url: photos[photoIndex].url)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white, lineWidth: 2))
                    .overlay {
                        if position == visible.count - 1 && overflow > 0 {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.45))
                                .overlay(
                                    Text("+\(overflow)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .rotationEffect(.degrees(Self.stackRotation(for: position)))
                    .offset(x: -CGFloat(distanceFromFront) * 16, y: -CGFloat(distanceFromFront) * 8)
                    .zIndex(Double(position))
            }
        }
        .padding(10)
        // One tap target for the whole fanned stack, not one per tiny
        // thumbnail — those overlap and are only ~44pt with most of that
        // covered by their neighbors, hard to land a tap on the one you
        // meant. A single tap just cycles the hero to the next photo.
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPhotoIndex = (safeSelectedIndex + 1) % photos.count
            }
        }
    }

    private static func stackRotation(for position: Int) -> Double {
        [-6, 4, -3][position % 3]
    }

    private var actionRow: some View {
        HStack(spacing: 20) {
            Button {
                Task { await postsStore.toggleLike(post) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: postsStore.isLiked(post) ? "heart.fill" : "heart")
                        .foregroundColor(postsStore.isLiked(post) ? .red : .black)
                    if postsStore.likeCount(for: post.id) > 0 {
                        Text("\(postsStore.likeCount(for: post.id))")
                            .font(AppFont.mediumLabel(13))
                            .foregroundColor(.appTextMuted)
                    }
                }
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { isCommentsExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.black)
                    if !comments.isEmpty {
                        Text("\(comments.count)")
                            .font(AppFont.mediumLabel(13))
                            .foregroundColor(.appTextMuted)
                    }
                }
            }

            Spacer()
        }
        .font(.system(size: 18, weight: .semibold))
        .buttonStyle(.plain)
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().background(Color.appBorder)

            ForEach(comments) { comment in
                HStack(alignment: .top, spacing: 8) {
                    AvatarView(imageName: postsStore.profile(for: comment.authorId)?.avatarURL, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(postsStore.profile(for: comment.authorId)?.displayName ?? "Someone")
                            .font(AppFont.pillLabelBold(12))
                            .foregroundColor(.black)
                        Text(comment.body)
                            .font(AppFont.mediumLabel(13))
                            .foregroundColor(.black)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add a comment...", text: $commentDraft)
                    .font(AppFont.mediumLabel(13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 0.5))

                Button(action: sendComment) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(commentDraft.trimmingCharacters(in: .whitespaces).isEmpty ? .appBorder : .black)
                }
                .disabled(commentDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            Task { await postsStore.fetchCommentsIfNeeded(for: post.id) }
        }
    }

    private func sendComment() {
        let text = commentDraft
        commentDraft = ""
        Task { await postsStore.addComment(to: post, body: text) }
    }

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

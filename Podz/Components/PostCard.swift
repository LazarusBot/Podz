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
    /// Fires only for a tap on the hero photo — everything else on the
    /// card (like, comment-expand, pod-arrow) keeps its own independent
    /// behavior. HomeView's feed uses this to push `PostDetailView` for
    /// this post. `nil` (the default) leaves the photo non-navigable,
    /// which is what `PostDetailView` itself wants when it re-renders
    /// this same card for its own "here's the post" content.
    var onTapPhoto: (() -> Void)? = nil
    /// Forces the full thread + input row open regardless of the local
    /// toggle below — off in the feed (comments there open via the
    /// comment button, same as always) and on inside `PostDetailView`.
    var showComments: Bool = false
    /// Caps how many comments actually render — `nil` (the default,
    /// every other caller) shows the whole thread. `PostDetailView` sets
    /// this to 1: that screen's own comment count already says there's a
    /// thread, and showing all of it inline pushed the "Add a comment"
    /// row (and everything else below the thread) arbitrarily far down
    /// the scroll.
    var maxVisibleComments: Int? = nil

    @ObservedObject private var postsStore = PostsStore.shared
    @ObservedObject private var podsStore = PodsStore.shared
    /// Which photo is currently the big "hero" when there's more than
    /// one — tapping a small stacked thumbnail promotes it here instead.
    @State private var selectedPhotoIndex = 0
    /// The comment button's own inline expand/collapse — independent of
    /// `showComments`, which only ever forces it *open* (never closed).
    @State private var isCommentsExpanded = false
    /// Set by tapping "Open" on the "+N comments" row — lifts
    /// `maxVisibleComments`'s cap for the rest of this card instance's
    /// lifetime. Local, not threaded back up to the caller: nothing else
    /// on screen needs to know the thread got expanded.
    @State private var showAllComments = false
    /// A comment's own name+body text block, measured — sizes that
    /// comment's avatar to match (instead of a flat 22pt sitting shorter
    /// than the two-line block beside it) and sizes the "+N comments"
    /// row below to match too, instead of both collapsing to their own
    /// shorter natural heights. Measured rather than guessed as a
    /// constant, same reasoning as `ModeSwitchPill`'s own
    /// `trackWidth`/`labelWidth`: real height here depends on live font
    /// metrics (two lines: name + body), not a number that's safe to
    /// hardcode.
    @State private var commentRowHeight: CGFloat = 0

    /// Backed by `PostsStore` rather than local `@State` — the feed's
    /// inline card and `PostDetailView`'s pushed one are two separate
    /// `PostCard` instances for the same post, and need to share whatever
    /// draft is currently typed if you back out and come back in.
    private var commentDraft: Binding<String> {
        Binding(
            get: { postsStore.commentDraft(for: post.id) },
            set: { postsStore.setCommentDraft($0, for: post.id) }
        )
    }

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
                    .font(AppFont.mediumLabel(13))
                    .foregroundColor(.black)
            }

            actionRow

            if isCommentsExpanded || showComments {
                commentsSection
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.r15)
                .fill(Color.appFieldBg)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.r15).strokeBorder(Color.appBorder, lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .frame(width: cardWidth, alignment: .leading)
        // Fetches regardless of whether the thread is actually shown —
        // the feed's inline card keeps comments collapsed by default, but
        // its comment *count* in actionRow still needs the real data.
        .task { await postsStore.fetchCommentsIfNeeded(for: post.id) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AvatarView(imageName: author?.avatarURL, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(author?.displayName ?? "Someone")
                    .font(AppFont.pillLabelBold(17))
                    .foregroundColor(.black)
                HStack(spacing: 4) {
                    if let pod {
                        Text(pod.name)
                            .font(AppFont.regularLabel(10))
                            .foregroundColor(.appTextMuted)
                        Text("·")
                            .font(AppFont.regularLabel(10))
                            .foregroundColor(.appTextMuted)
                    }
                    Text(Self.relativeTime(post.createdAt))
                        .font(AppFont.regularLabel(10))
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
            .accessibilityLabel("View pod")
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
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.r12, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { onTapPhoto?() }
        } else {
            ZStack(alignment: .bottomTrailing) {
                heroPhoto
                    .contentShape(Rectangle())
                    .onTapGesture { onTapPhoto?() }
                // photoStack sits on top with its own tap gesture (cycles
                // the hero) — taps landing on it resolve there, not here.
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
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r12, style: .continuous))
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
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.r8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.r8).strokeBorder(Color.white, lineWidth: 2))
                    .overlay {
                        if position == visible.count - 1 && overflow > 0 {
                            RoundedRectangle(cornerRadius: AppRadius.r8)
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
            withAnimation(.easeInOut(duration: AppMotion.snappy)) {
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
                            .font(AppFont.regularLabel(13))
                            .foregroundColor(.appTextMuted)
                    }
                }
            }
            .accessibilityLabel(postsStore.isLiked(post) ? "Unlike" : "Like")

            Button {
                withAnimation(.easeOut(duration: AppMotion.snappy)) { isCommentsExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.black)
                    if !comments.isEmpty {
                        Text("\(comments.count)")
                            .font(AppFont.regularLabel(13))
                            .foregroundColor(.appTextMuted)
                    }
                }
            }
            .accessibilityLabel(isCommentsExpanded ? "Hide comments" : "Show comments")

            Spacer()
        }
        .font(.system(size: 18, weight: .semibold))
        .buttonStyle(.plain)
    }

    /// `comments`, capped to `maxVisibleComments` when set — lifted once
    /// "Open" (see `hiddenCommentsCount`'s own row) has been tapped.
    private var visibleComments: [PostComment] {
        guard !showAllComments, let maxVisibleComments else { return comments }
        // `comments` is oldest-first (`fetchCommentsIfNeeded`'s own
        // `.order("created_at")`, ascending) — `.suffix`, not `.prefix`,
        // is what actually keeps the most recently posted comment(s)
        // visible instead of the oldest.
        return Array(comments.suffix(maxVisibleComments))
    }

    /// How many comments the cap is currently hiding — 0 once expanded,
    /// so the "+N comments" row's own `if` below just disappears rather
    /// than needing a separate condition to hide it.
    private var hiddenCommentsCount: Int {
        comments.count - visibleComments.count
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().background(Color.appBorder)

            if hiddenCommentsCount > 0 {
                Button {
                    withAnimation(.easeOut(duration: AppMotion.snappy)) {
                        showAllComments = true
                    }
                } label: {
                    HStack {
                        Text("+ \(hiddenCommentsCount) comment\(hiddenCommentsCount == 1 ? "" : "s")")
                            .font(AppFont.regularLabel(12))
                            .foregroundColor(.appTextMuted)
                        Spacer()
                        Text("Open")
                            .font(AppFont.mediumLabel(12))
                            .foregroundColor(.appTextMuted)
                            .underline()
                    }
                    // Matches a real comment row's own height instead of
                    // collapsing to this row's shorter single line — see
                    // `commentRowHeight`'s own comment.
                    .frame(height: commentRowHeight > 0 ? commentRowHeight : nil)
                }
                .buttonStyle(.plain)

                // Same hairline as between two comments — keeps this row
                // reading as part of the same list rhythm instead of
                // sitting apart from it.
                Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
            }

            ForEach(Array(visibleComments.enumerated()), id: \.element.id) { index, comment in
                HStack(alignment: .center, spacing: 8) {
                    // Sized to the text block's own measured height (see
                    // below), not a fixed 22 — a flat 22pt avatar sat
                    // noticeably shorter than the two-line name+body
                    // block beside it, leaving `.top` alignment reading
                    // as "avatar floating at the top" rather than
                    // "avatar and text filling the same row."
                    AvatarView(imageName: postsStore.profile(for: comment.authorId)?.avatarURL, size: commentRowHeight > 0 ? commentRowHeight : 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(postsStore.profile(for: comment.authorId)?.displayName ?? "Someone")
                            // Real Inter (Medium, not Darker Grotesque
                            // Bold) — the name and body were mixing two
                            // different font families in the same small
                            // block, which is what read as misaligned/
                            // "fonts off": Darker Grotesque and Inter
                            // have different line-height and apparent
                            // size at the same point value (Darker
                            // Grotesque runs visually smaller — same
                            // reason FriendsView's own name/username
                            // pairing needed rebalancing earlier). One
                            // family, two weights, is what actually
                            // reads as one coherent row.
                            //
                            // Same 12pt as the body below, not smaller —
                            // a name reading *smaller* than its own
                            // comment had the hierarchy backwards; weight
                            // (SemiBold vs Regular) is what should tell
                            // them apart, not size.
                            .font(AppFont.semiBoldLabel(12))
                            .foregroundColor(.black)
                        Text(comment.body)
                            // Real Inter Regular, not Medium — matches
                            // every other subtitle-role text fixed
                            // elsewhere (see `ProfileRows.swift`'s
                            // `ProfileAccountRow`), sized down with it.
                            .font(AppFont.regularLabel(12))
                            .foregroundColor(.black)
                    }
                    // Measures just this text block's own height (not
                    // the whole row, which would create a feedback loop
                    // once the avatar's size is driven by it too) —
                    // that's what `commentRowHeight` actually names.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { commentRowHeight = $0 }
                }

                // Between comments only, not after the last one (that'd
                // just crowd the input row right below it). Same exact
                // construction as `ProfileAccountRow`/`ProfileMenuRow`'s
                // own bottom hairline (a plain `Divider()` doesn't share
                // its thickness — that one defaults to SwiftUI's own
                // ~1pt line, not this app's 0.5pt one).
                if index < visibleComments.count - 1 {
                    Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
                }
            }

            // Same hairline as every other divider in this section — a
            // plain `Divider()` here was a leftover from before those
            // got tuned to match `ProfileAccountRow`/`ProfileMenuRow`'s
            // own hairline; this one just never got updated with them.
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)

            HStack(spacing: 8) {
                TextField("Add a comment...", text: commentDraft)
                    // Real Inter Regular, not Medium — same fix/reasoning
                    // as the comment body just above.
                    .font(AppFont.regularLabel(12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 0.5))

                Button(action: sendComment) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(commentDraft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty ? .appBorder : .black)
                }
                .disabled(commentDraft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Send comment")
            }
        }
    }

    private func sendComment() {
        let text = commentDraft.wrappedValue
        commentDraft.wrappedValue = ""
        Task { await postsStore.addComment(to: post, body: text) }
    }

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .numeric
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

//
//  PodDetailView.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

import SwiftUI

/// node 4028:586 — pod detail screen. No bottom tab bar here — MainTabView's
/// bar stays visible underneath, same pattern as ProfileEditView.
struct PodDetailView: View {
    let pod: Pod
    var onBack: () -> Void

    @State private var rooms: [PodRoom] = []
    @State private var isLoadingRooms = true
    /// `beds_available_now` RPC result — `pod.bedsTotal` minus the
    /// busiest night's worth of everyone's confirmed reservations over the
    /// next 30 days, computed server-side since client-side RLS only ever
    /// exposes your own reservations. `nil` until it loads (or if the RPC
    /// call fails), in which case the header pill falls back to the
    /// static total.
    @State private var liveBedsAvailable: Int?
    @State private var heroPhotoURLs: [String]
    /// Optional — required by `.scrollPosition(id:)`'s binding type.
    @State private var heroPageIndex: Int? = 0
    @ObservedObject private var likesStore = LikesStore.shared
    @State private var showFolderPicker = false
    /// Drives the reservation bar growing in place to show the booking
    /// form — same idea as CategoryScroller's `filters.isExpanded`, not a
    /// `.sheet()` presentation.
    @State private var isReservationExpanded = false
    /// Vertical scroll content offset — 0 at rest, grows positive
    /// scrolling down. `onScrollGeometryChange` is the reliable way to
    /// track this; a GeometryReader-in-a-PreferenceKey probe was tried
    /// twice for this screen (once for this, once for the hero's measured
    /// position directly) and silently never fired either time.
    @State private var scrollOffset: CGFloat = 0
    /// Rendered once (see `.task`), not recomputed as part of `body` —
    /// `ShareLink`'s `preview:` needs a ready `Image` synchronously, and
    /// this view's body re-evaluates on every scroll frame (chromeOpacity),
    /// so rendering the card there would mean re-running ImageRenderer
    /// dozens of times a second.
    @State private var shareCardImage: UIImage?

    /// Single source of truth for the hero's height — referenced both by
    /// `heroImage`'s own frame and by `chromeOpacity`'s arithmetic (hero's
    /// bottom edge = heroHeight - scrollOffset), so they can't drift apart.
    private let heroHeight: CGFloat = 340

    /// Same boilerplate text for every pod for now — not pod-specific yet.
    private let cancellationPolicy = "For organisational reasons we ask you to inform us immediately of any changes or cancellations to your reservation. This will allow us to provide accomodation for other shelter seeking mountaineers."

    /// Same placeholder-for-every-pod pattern as `cancellationPolicy` —
    /// there's no host model/backend data yet, just a generic "who's
    /// looking after this place" blurb until one exists.
    private let hostName = "The Podz Team"
    private let hostBlurb = "Taking care of this refuge and everyone who stays."

    /// Seeded from the Home card's already-fetched primary photo so the
    /// hero shows something on the very first frame — the full ordered
    /// carousel only arrives once `photos(forPodId:)` resolves in `.task`.
    init(pod: Pod, onBack: @escaping () -> Void) {
        self.pod = pod
        self.onBack = onBack
        let seed = PodsStore.shared.primaryPhotoByPodId[pod.id]
        _heroPhotoURLs = State(initialValue: seed.map { [$0] } ?? [])
    }

    var body: some View {
        // Every section from Host down (Host included, right after the
        // header) shares one `SectionLabel` eyebrow and gets a full-width
        // `sectionDivider` between it and the next — see that property's
        // own doc comment for why the gap lives entirely in the divider
        // now, not split between it and each section's own top padding.
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage
                    quickStatsRow
                    sectionDivider
                    hostSection
                    sectionDivider
                    availabilitySection
                    sectionDivider
                    pricesSection
                    sectionDivider
                    whatToExpectSection
                    // Extra clearance (not the old 80) — the floating
                    // reservation card now sits above the app's own
                    // floating tab bar, and content needs to clear both.
                    Color.clear.frame(height: 160)
                }
            }
            // contentOffset.y is 0 at rest and grows positive scrolling
            // down.
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newValue in
                scrollOffset = newValue
            }
            .scrollEdgeEffectStyle(.hard, for: .top)
            .ignoresSafeArea(edges: .top)
            .background(Color.appHomeBackground)
            // Tap-outside-to-dismiss for the reservation panel — same
            // pattern HomeView uses for its own search/filters pill.
            // Only intercepts anything while the panel is actually open;
            // a plain tap on the scrolling content otherwise reaches it
            // as normal.
            .contentShape(Rectangle())
            .onTapGesture {
                if isReservationExpanded {
                    isReservationExpanded = false
                }
            }

            topBar

            reservationBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        // Refreshes the header's live count the moment the bar collapses —
        // a reservation made just now should be reflected immediately,
        // not only the next time this screen happens to reload. Fires
        // whether it collapsed via a cancel (the toggle button again) or
        // a successful submission (ReservationSheet's own onDismiss).
        .onChange(of: isReservationExpanded) { _, isShowing in
            guard !isShowing else { return }
            Task { liveBedsAvailable = await PodsStore.shared.bedsAvailableNow(forPodId: pod.id) }
        }
        .task {
            async let roomsTask = PodsStore.shared.rooms(forPodId: pod.id)
            async let photosTask = PodsStore.shared.photos(forPodId: pod.id)
            async let bedsTask = PodsStore.shared.bedsAvailableNow(forPodId: pod.id)
            let (fetchedRooms, fetchedPhotos, fetchedBeds) = await (roomsTask, photosTask, bedsTask)
            rooms = fetchedRooms
            isLoadingRooms = false
            liveBedsAvailable = fetchedBeds
            if !fetchedPhotos.isEmpty {
                heroPhotoURLs = fetchedPhotos
            }
            // Waits for the actual photo instead of just checking the
            // cache — CachedAsyncImage's own download for the hero runs
            // as a separate, independent task, so grabbing whatever's in
            // ImageCache right here raced it and often lost, rendering
            // the card with a blank gray box in place of the photo.
            let photo = await loadedPhoto(urlString: heroPhotoURLs.first)
            let renderer = ImageRenderer(content: PodShareCard(pod: pod, photo: photo))
            renderer.scale = UIScreen.main.scale
            shareCardImage = renderer.uiImage
        }
    }

    // MARK: - Hero

    /// Overscroll pull-down stretches the photo taller to fill the gap
    /// instead of leaving a gray strip above it. Derived from the same
    /// `scrollOffset` `topBar` already tracks (contentOffset.y goes
    /// negative past the top, standard UIScrollView bounce), not a second,
    /// independent GeometryReader — that reads `.frame(in: .global)`,
    /// which re-lays-out on every frame and was fighting the hero's own
    /// TabView for layout during horizontal swipes, causing visible jumps.
    private var heroStretch: CGFloat {
        max(0, -scrollOffset)
    }

    private var heroImage: some View {
        Group {
            // Most pods won't have one yet — the scan is optional and
            // gated to LiDAR devices (see PodScanCaptureView) — so this
            // falls back to the untouched photo carousel for everyone else.
            if let modelURL = pod.modelURL {
                Pod3DModelView(modelURL: modelURL, fallbackPhotoURL: heroPhotoURLs.first)
            } else {
                heroGallery
            }
        }
        .overlay(heroOverlayContent)
        // On top of heroOverlayContent's gradient, not under it (that's
        // where this lived when it was still attached inside
        // `heroGallery` itself) — the stack's own white borders and
        // shadow read a lot cleaner sitting above the scrim than muddied
        // underneath it. `pod.modelURL == nil` since a 3D-scanned pod's
        // hero is `Pod3DModelView`, never `heroGallery`, so there's no
        // photo stack to show there at all.
        .overlay(alignment: .bottomTrailing) {
            if pod.modelURL == nil, heroPhotoURLs.count > 1 {
                heroPhotoStack
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight + heroStretch)
        .clipped()
        .offset(y: -heroStretch)
    }

    /// Editorial treatment — name/location/live-availability live directly
    /// on the photo (gradient scrim underneath), not in a separate white
    /// block below it. Replaces the old standalone `header`. Non-
    /// interactive throughout (`.allowsHitTesting(false)`) so it never
    /// steals `Pod3DModelView`'s own drag-to-orbit gesture on pods with a
    /// scan — this sits in the same `.overlay` z-order, right on top of it.
    private var heroOverlayContent: some View {
        ZStack(alignment: .bottom) {
            // Stronger and taller than a first pass, which left the
            // caption unreadable on a bright/snowy photo — clear through
            // the top half so the photo itself isn't needlessly darkened,
            // then ramping hard through the bottom half to a near-opaque
            // black right where the text sits, not a gentle fade that
            // still lets a light photo show through behind white text.
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6), .black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(pod.name)
                    .font(AppFont.pillLabel(30))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let region = pod.region {
                        Text(region)
                        Circle().fill(Color.white.opacity(0.6)).frame(width: 3, height: 3)
                    }
                    Text(pod.country)
                }
                // 16, not 13 — at 13/0.7 this dropped in size *and*
                // opacity at once against the 30pt name, reading as an
                // afterthought rather than a deliberate secondary line.
                // Still clearly one step down from the name, just with
                // enough presence to actually be read at a glance, not
                // squinted at.
                .font(AppFont.pillLabelMedium(16))
                .foregroundColor(.white.opacity(0.85))
            }
            // A soft shadow on the text itself, independent of the
            // gradient above — belt-and-suspenders for a photo bright
            // enough that even the strong gradient stop still leaves
            // white text marginal right at the edge of the readable
            // region.
            .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Top bar (back/heart/share — persistent, never re-instantiated)

    /// Back button and heart/share are ONE instance each, always on screen
    /// at the same fixed position — not a "hero row" and a separate
    /// "compact header row" crossfading between two different instances,
    /// which visibly popped/jumped at the swap. Only the chrome around
    /// them (the opaque bar, the small pod thumbnail, the white pill
    /// backing heart/share) fades with scroll; the buttons themselves
    /// never move and are never duplicated.
    private var topBar: some View {
        HStack(spacing: 12) {
            CircleIconButton(
                systemName: "chevron.left",
                backgroundOpacity: 1 - chromeOpacity,
                accessibilityLabel: "Back",
                action: onBack
            )

            PodPhoto(url: heroPhotoURLs.first)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.r10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.r10, style: .continuous)
                        .strokeBorder(Color.appBorder, lineWidth: 0.5)
                )
                .opacity(chromeOpacity)

            Spacer()

            likeAndShareButtons(pillOpacity: 1 - chromeOpacity)
        }
        // Matches the page's horizontal inset (24) so the back button
        // lines up with the pod name directly beneath it.
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        // A `.background` sized off this HStack's own frame, not a
        // separately hardcoded height — the previous version guessed 60pt
        // for the background while the actual row measured something
        // else, leaving the background not fully covering it. Only the
        // background ignores the top safe area (bleeds up behind the
        // status bar/notch so there's no gap of hero photo peeking through
        // above it once opaque); the HStack itself stays safe-area-aware
        // so the buttons don't shift.
        .background(
            Color.appHomeBackground
                .opacity(chromeOpacity)
                .ignoresSafeArea(edges: .top)
        )
        .overlay(alignment: .bottom) {
            Divider().opacity(chromeOpacity)
        }
    }

    /// 0 over the photo, 1 once scrolled — drives the background bar, the
    /// pod thumbnail, and the white pill behind heart/share (which fades
    /// OUT as the opaque bar fades IN behind it; a separate white pill on
    /// top of an already-white bar would be redundant). Computed from the
    /// hero's actual bottom edge (heroHeight - scrollOffset — the photo's
    /// top sits at screen y0 since the ScrollView ignores the top safe
    /// area) rather than a bare scroll-offset number, so tuning
    /// `fadeStart`/`fadeEnd` stays meaningful as "how far the photo's
    /// bottom edge still has to travel." Starts while that edge is still
    /// 220pt above the top of the screen and finishes by 100pt — fully
    /// opaque with the photo still visibly there, not right as it clears.
    private var chromeOpacity: Double {
        let heroBottomY = heroHeight - scrollOffset
        let fadeStart: CGFloat = 220
        let fadeEnd: CGFloat = 100
        return Double(min(max((fadeStart - heroBottomY) / (fadeStart - fadeEnd), 0), 1))
    }

    @ViewBuilder
    private func likeAndShareButtons(pillOpacity: Double) -> some View {
        // Both icons get an identical 44x44 frame — Apple's HIG minimum
        // tap target — with the glyph centered inside, which is what makes
        // them align position-wise. "heart"'s own glyph still renders
        // visually smaller than "square.and.arrow.up" at the same point
        // size though (SF Symbols aren't optically equalized across
        // glyphs) — bumped a couple points to actually look the same
        // size, not just centered in the same box.
        HStack(spacing: 0) {
            Button {
                if likesStore.isLiked(pod) {
                    Task { await likesStore.removeLike(pod) }
                } else {
                    showFolderPicker = true
                }
            } label: {
                Image(systemName: likesStore.isLiked(pod) ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(likesStore.isLiked(pod) ? .red : .black)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .likeFolderPicker(for: pod, isPresented: $showFolderPicker)
            .accessibilityLabel(likesStore.isLiked(pod) ? "Remove from likes" : "Add to likes")

            // Sharing the link itself, not the rendered PNG — a plain
            // image attachment isn't tappable to open the app on its own,
            // and offering both as alternate Transferable representations
            // (tried first) was ambiguous: some destinations took the PNG,
            // Messages additionally surfaced the link as its own separate
            // text bubble. A URL with a custom SharePreview image is the
            // one combination that's reliably both "looks like the card"
            // and "tapping it opens the app," as a single shared item.
            ShareLink(
                item: deepLinkURL,
                preview: SharePreview(pod.name, image: sharePreviewImage)
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Share")
        }
        .padding(.horizontal, 4)
        .background(Capsule().fill(Color.white.opacity(0.9 * pillOpacity)))
        .overlay(Capsule().strokeBorder(Color.appBorder.opacity(pillOpacity), lineWidth: 0.5))
    }

    /// A horizontal, paging `ScrollView` — not `TabView(.page)`. TabView's
    /// paging is UIKit-page-view-controller-backed underneath, and nested
    /// inside this screen's own vertical ScrollView, the two didn't always
    /// agree on which one owned a given drag: some swipes needed a second
    /// attempt to actually land on the next page. Two `ScrollView`s (same
    /// SwiftUI primitive, just orthogonal axes) negotiate that nesting far
    /// more reliably than a TabView does.
    ///
    /// Always renders the ForEach/paging structure, even for a single
    /// photo — not a plain `PodPhoto` that switches to this once the full
    /// gallery arrives. That kind of `if/else` branch swap is what SwiftUI
    /// treats as tearing down and rebuilding the whole subtree: the first
    /// photo's `CachedAsyncImage` got recreated the moment `.task`
    /// replaced the single-element seed with the fetched array, resetting
    /// its `@State` to nil for a frame — a flash, even though that photo
    /// was already cached. Keeping the same structure the whole time means
    /// index 0's view identity (same `ForEach` id) survives that update.
    private var heroGallery: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(heroPhotoURLs.enumerated()), id: \.offset) { index, url in
                    // `.containerRelativeFrame(.horizontal)`, not a
                    // manually-measured-and-cached width — that GeometryReader
                    // + PreferenceKey approach (tried twice, most recently
                    // rounding the measured value to kill a suspected
                    // fractional-pixel drift) still occasionally let
                    // `.scrollTargetBehavior(.paging)`'s snap points land
                    // between two pages instead of squarely on one — a
                    // separately-stored width can always go one layout
                    // pass stale relative to the scroll container's own
                    // current size. `containerRelativeFrame` reads that
                    // container's width directly, on the same layout pass,
                    // with nothing to fall out of sync.
                    PodPhoto(url: url)
                        .containerRelativeFrame(.horizontal)
                        .frame(height: heroHeight + heroStretch)
                        .clipped()
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollDisabled(heroPhotoURLs.count <= 1)
        .scrollPosition(id: $heroPageIndex)
    }

    /// Clamped so a stale/nil index never reads out of bounds — same
    /// reasoning as PostCard's own `safeSelectedIndex`.
    private var safeHeroIndex: Int {
        min(heroPageIndex ?? 0, max(heroPhotoURLs.count - 1, 0))
    }

    /// Up to 3 of the photos *coming next* in swipe order (wrapping past
    /// the end), fanned over the hero's bottom-trailing corner — the same
    /// visual language as `PostCard`'s own photo stack (Figma's
    /// "Frame 71"), adapted for an ordered, swipeable carousel rather
    /// than PostCard's cycle-any-photo one: this shows what a swipe would
    /// land on next, not just "the other photos" in arbitrary order.
    /// Tapping the stack advances one photo forward, same direction a
    /// swipe goes — the real swipe gesture itself is still the paging
    /// `ScrollView` above (already proven to coexist with this screen's
    /// own vertical scroll; a raw `DragGesture` here risked fighting it).
    private var heroPhotoStack: some View {
        let upcoming = (1...min(3, heroPhotoURLs.count - 1)).map { (safeHeroIndex + $0) % heroPhotoURLs.count }
        let overflowCount = heroPhotoURLs.count - 1 - upcoming.count

        return ZStack(alignment: .bottomTrailing) {
            ForEach(Array(upcoming.enumerated()), id: \.offset) { position, photoIndex in
                let distanceFromFront = upcoming.count - 1 - position
                PodPhoto(url: heroPhotoURLs[photoIndex])
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.r8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.r8).strokeBorder(Color.white, lineWidth: 2))
                    .overlay {
                        if position == upcoming.count - 1 && overflowCount > 0 {
                            RoundedRectangle(cornerRadius: AppRadius.r8)
                                .fill(Color.black.opacity(0.45))
                                .overlay(
                                    Text("+\(overflowCount)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .rotationEffect(.degrees([-6, 4, -3][position % 3]))
                    .offset(x: -CGFloat(distanceFromFront) * 16, y: -CGFloat(distanceFromFront) * 8)
                    .zIndex(Double(position))
            }
        }
        .padding(14)
        // One tap target for the whole fanned stack, not one per tiny
        // thumbnail — same reasoning as PostCard's identical choice.
        .contentShape(Rectangle())
        .onTapGesture {
            // No `withAnimation` — an animated `.scrollPosition(id:)`
            // change is a multi-frame scroll transition that a swipe
            // starting right after can interrupt mid-flight, and
            // `.scrollTargetBehavior(.paging)`'s own snap logic assumes
            // it's starting from a settled, page-aligned position. That
            // interrupted-animation state is exactly what left the
            // scroll view stuck between two pages. An instant jump has
            // no multi-frame window for a swipe to land inside.
            heroPageIndex = (safeHeroIndex + 1) % heroPhotoURLs.count
        }
    }

    /// The branded card — rendered once in `.task`, not here, so this stays
    /// a cheap read on every body evaluation. Falls back to the plain hero
    /// photo for the brief window before that render completes.
    private var sharePreviewImage: Image {
        if let shareCardImage {
            return Image(uiImage: shareCardImage)
        }
        if let cached = ImageCache.shared.image(for: heroPhotoURLs.first ?? "") {
            return Image(uiImage: cached)
        }
        return Image(systemName: "photo")
    }

    private var deepLinkURL: URL {
        URL(string: "podz://pod/\(pod.id.uuidString)")!
    }

    /// Same `ImageLoader` pipeline `CachedAsyncImage` uses, but awaited
    /// directly here instead of firing off as its own independent
    /// `.task` — this is what guarantees the share card actually has the
    /// photo by the time it renders.
    private func loadedPhoto(urlString: String?) async -> UIImage? {
        guard let urlString else { return nil }
        if let cached = ImageCache.shared.image(for: urlString) { return cached }
        guard let image = try? await ImageLoader.load(urlString: urlString) else { return nil }
        ImageCache.shared.set(image, for: urlString)
        return image
    }

    // MARK: - Quick stats

    /// Name/region/country/altitude used to live here, in a plain white
    /// block below the hero — moved onto the photo itself
    /// (`heroOverlayContent`). What's left is the three facts someone
    /// scans for first: altitude, capacity, price. All three are real
    /// data already on `pod`/`rooms`, not new fields — an em dash where
    /// the pod genuinely doesn't have that data yet (most commonly price,
    /// since `pricesSection` below already shows "No rooms listed yet"
    /// for the same reason), same honesty as every other empty state on
    /// this screen.
    private var quickStatsRow: some View {
        HStack(spacing: 0) {
            quickStat(value: pod.altitudeM.map { "\($0) m" } ?? "—", label: "Altitude")
            Rectangle().fill(Color.appBorder).frame(width: 0.5, height: 32)
            quickStat(value: pod.bedsTotal.map { "\($0)" } ?? "—", label: "Beds")
            Rectangle().fill(Color.appBorder).frame(width: 0.5, height: 32)
            quickStat(value: priceRangeText ?? "—", label: "Per night")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
    }

    private func quickStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.pillLabel(19))
                .foregroundColor(.appTextPrimary)
            Text(label.uppercased())
                .font(AppFont.mediumLabel(11))
                .tracking(0.3)
                .foregroundColor(.appTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    /// From the same `rooms` `pricesSection` already fetched — not a
    /// separate lookup. `nil` while rooms are still loading or genuinely
    /// empty, same case `pricesSection` itself already handles.
    private var priceRangeText: String? {
        guard !rooms.isEmpty else { return nil }
        guard let lo = rooms.map(\.priceMin).min(), let hi = rooms.map(\.priceMax).max() else { return nil }
        return lo == hi ? "\(Int(lo))€" : "\(Int(lo))-\(Int(hi))€"
    }

    // MARK: - Host

    /// Section title uses `SectionLabel` now — same quiet uppercase
    /// eyebrow as Profile/Friends/MyReservations, and every other section
    /// on this screen from here down. `SectionLabel` already carries its
    /// own 24pt horizontal + 20pt top / 6pt bottom padding (it's designed
    /// to sit directly in a full-bleed list, not nested inside another
    /// padded container) — so unlike the old plain-`Text` titles, nothing
    /// here wraps it in a matching `.padding(.horizontal, 24)`. That was
    /// the actual bug behind the label reading as not-quite-left-aligned:
    /// it was double-inset (its own 24 plus the section's own 24) while
    /// the content below only had one. Only the content below gets its
    /// own `.padding(.horizontal, 24)` now, so both line up on the same
    /// left edge.
    private var hostSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: "Host")

            HStack(spacing: 14) {
                AvatarView(imageName: nil, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hosted by \(hostName)")
                        .font(AppFont.pillLabelBold(17))
                        .foregroundColor(.appTextPrimary)
                    Text(hostBlurb)
                        .font(AppFont.regularLabel(14))
                        .foregroundColor(.appTextMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, sectionBottomPadding)
        }
    }

    /// Every section below `SectionLabel` ends with this much bottom
    /// padding on its content — matching `SectionLabel`'s own fixed 20pt
    /// top padding (plus `sectionDivider`'s own share below), so a
    /// section's gap to the divider *above* it and to the divider
    /// *below* it read the same, instead of the label sitting much
    /// further from the line above it than the content sits from the
    /// line below it.
    private let sectionBottomPadding: CGFloat = 20

    /// Hairline separator between every section from Host down — full
    /// width (no horizontal inset, unlike the sections themselves). Only
    /// a small padding of its own now — see `sectionBottomPadding`'s doc
    /// comment for where the rest of the section-to-section gap actually
    /// lives; piling a big gap on both this *and* every section's own
    /// padding is what made the two edges of a section uneven in the
    /// first place. A plain `Divider()` renders in iOS's own system
    /// separator color, which doesn't reliably match `.appBorder` — the
    /// token every other stroke on this screen (topBar's button, the
    /// reservation bar, room cards, the map) already uses. A `Rectangle`
    /// gives direct, reliable control over that color instead.
    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.appBorder)
            .frame(height: 0.5)
            .padding(.vertical, 4)
    }

    // MARK: - Availability

    /// Was a small pill next to the altitude chip in `header`; promoted
    /// to its own section so it reads as real content, not a stat crammed
    /// into the title row.
    private var displayedBedsAvailable: Int? {
        liveBedsAvailable ?? pod.bedsTotal
    }

    /// Every tier gets an honest caption and its own shade of the same
    /// green — not just a "plenty" nudge that only ever shows up at the
    /// top end and leaves every other level of availability with a bare
    /// number and nothing else. Thresholds are against the pod's own
    /// total capacity, not an absolute count, so a 6-bed hut and a
    /// 60-bed refuge both read as "full" or "plenty" at the same
    /// relative point. Still no fabricated claim anywhere in here — every
    /// caption is a direct read of the same real count the number above
    /// it already shows, same reasoning as the single "plenty" nudge this
    /// replaced.
    private enum AvailabilityTier {
        case full, low, medium, high

        var caption: String {
            switch self {
            case .full: "Check back for new openings."
            case .low: "Filling up fast."
            case .medium: "Good availability."
            case .high: "Plenty of space right now."
            }
        }

        /// One hue throughout (red stays reserved for `.full`) — just
        /// fading as availability drops, not switching color family.
        /// Full strength at `.high` only, so `appAvailableGreen`'s own
        /// doc comment (verified to read on a dark background at full
        /// opacity) still covers the one tier that actually uses it at
        /// 100%.
        var tint: Color {
            switch self {
            case .full: .red
            case .low: .appAvailableGreen.opacity(0.6)
            case .medium: .appAvailableGreen.opacity(0.8)
            case .high: .appAvailableGreen
            }
        }
    }

    /// `nil` only when there's no beds data at all for this pod (see
    /// `availabilitySection`'s own empty-state branch) — once `beds` is
    /// known, every pod lands in exactly one tier, `.full` included.
    /// Unknown total (old pods, pre-dates `bedsTotal` being required)
    /// falls to `.medium` — not `.high`, which would overstate a number
    /// we have no ratio to actually judge.
    private var availabilityTier: AvailabilityTier? {
        guard let beds = displayedBedsAvailable else { return nil }
        guard beds > 0 else { return .full }
        guard let total = pod.bedsTotal, total > 0 else { return .medium }
        let ratio = Double(beds) / Double(total)
        if ratio >= 0.5 { return .high }
        if ratio >= 0.2 { return .medium }
        return .low
    }

    private var availabilitySection: some View {
        // 8, not the 16 every other section uses between its label and
        // content — this section's own content is just two short lines
        // (the count, the caption), not a photo/paragraph/avatar row, so
        // the wider gap read as too loose for how little is actually
        // there.
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Availability")

            VStack(alignment: .leading, spacing: 12) {
                if let beds = displayedBedsAvailable, let tier = availabilityTier {
                    HStack(alignment: .lastTextBaseline) {
                        // SemiBold, not Medium — this is the single biggest
                        // number on the screen; Medium at this size read as
                        // bigger-but-weaker than the Bold/Black text
                        // everywhere else something's meant to stand out,
                        // inverting how weight tracks size on this page.
                        Text(tier == .full ? "Fully booked" : "\(beds) available")
                            .font(AppFont.pillLabelSemiBold(22))
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                        if let total = pod.bedsTotal {
                            Text("out of \(total)")
                                .font(AppFont.mediumLabel(12))
                                .foregroundColor(.appTextMuted)
                        }
                    }

                    // Same real ratio the text above already states, just
                    // rendered as filled/empty segments instead of a bare
                    // number — monochrome throughout, not tier.tint: the
                    // one color on this whole screen that carries real
                    // meaning is the small status dot on the hero photo,
                    // and the caption line below already spells out
                    // "fully booked" in words, so nothing here needs a
                    // second color to repeat the same fact.
                    availabilityGauge

                    // 13, not 16 — matches the caption/helper size used
                    // elsewhere (ReservationSheet's "3 nights", FilterRow's
                    // helper text), reading as a caption under the count
                    // rather than a second line of equal weight.
                    Text(tier.caption)
                        .font(AppFont.mediumLabel(13))
                        .foregroundColor(.appTextMuted)
                } else {
                    // Parity with `pricesSection`'s "No rooms listed yet"
                    // — `pod.bedsTotal` is part of the initial `Pod`
                    // value, not fetched async, so this isn't a loading
                    // flash: it means no capacity data exists for this
                    // pod at all. A blank gap under the label read as
                    // broken, not empty.
                    Text("Availability info not listed yet")
                        .font(AppFont.mediumLabel(16))
                        .foregroundColor(Color.appTextSubtle)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, sectionBottomPadding)
        }
    }

    /// 10 segments, filled left-to-right by the same `beds`/`bedsTotal`
    /// ratio `availabilityTier` already computes — a derived read of real
    /// numbers already on screen, not a new metric.
    private var availabilityGauge: some View {
        let segmentCount = 10
        let filled: Int = {
            guard let beds = displayedBedsAvailable, let total = pod.bedsTotal, total > 0 else { return 0 }
            let ratio = Double(beds) / Double(total)
            return max(0, min(segmentCount, Int((ratio * Double(segmentCount)).rounded())))
        }()
        return HStack(spacing: 3) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(index < filled ? Color.appTextPrimary : Color.appBorder)
                    .frame(height: 5)
            }
        }
    }

    /// Same source as `availabilitySection`'s count — while
    /// `liveBedsAvailable` is still loading, falls back to the static
    /// total rather than blocking the button on a number that hasn't
    /// arrived yet.
    private var canReserve: Bool {
        (displayedBedsAvailable ?? 1) > 0
    }

    /// `BottomTabBar` (MainTabView) sits with its bottom edge 24pt above
    /// the true screen edge (`barBottomGap`) and is ~52pt tall itself
    /// (26pt icons + 13pt vertical padding each side) — so its top edge
    /// lands ~76pt up. This is this bar's own dedicated clearance above
    /// that top edge, not just enough to avoid touching it.
    private let gapAboveGlobalTabBar: CGFloat = 20
    private var globalTabBarTopEdge: CGFloat { 76 }

    /// node 3850:1245's "Nav Elements" — a whole floating bar of its own,
    /// stacked above the app's global floating tab bar (MainTabView's
    /// `BottomTabBar`), not a button embedded in the scrolling content.
    /// Deliberately a dark glass tint rather than BottomTabBar's white one,
    /// so this bar reads as distinct from the app's global tab bar. Grows
    /// downward in place to reveal the reservation form — same pattern as
    /// CategoryScroller's `filtersPanel` growing inside HomeSearchRow —
    /// rather than presenting `ReservationSheet` as a separate `.sheet()`.
    private var reservationBar: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    reservationBarBody
                        .glassEffect(.regular.tint(.black.opacity(0.1)), in: reservationBarShape)
                }
            } else {
                // Pre-iOS 26 fallback: closest approximation with materials —
                // same as BottomTabBar's own fallback, but dark-tinted.
                reservationBarBody
                    .background(
                        reservationBarShape
                            .fill(.ultraThinMaterial)
                            .overlay(reservationBarShape.fill(Color.black.opacity(0.1)))
                    )
            }
        }
        .overlay(reservationBarShape.strokeBorder(Color.appBorder, lineWidth: 0.5))
        // Without this, the form panel's grow/shrink transition briefly
        // renders past the bar's own rounded edge instead of staying
        // clipped inside it — same reasoning as HomeSearchRow's own
        // `.clipShape` after its `.background`.
        .clipShape(reservationBarShape)
        .padding(.horizontal, 24)
        .padding(.bottom, globalTabBarTopEdge + gapAboveGlobalTabBar)
        // nil, not just a fast duration — even AppMotion.quick was still
        // visibly catching up mid-grow. An instant snap governs the
        // shape everywhere it's used above (glassEffect/overlay/
        // clipShape); reservationBarBody's own nested `.animation`
        // overrides this back to a real animation for just the height
        // change, since that one sits closer to the actual content that
        // grows — so the corner is simply never mid-transition, while
        // the panel below it still grows smoothly.
        .animation(nil, value: isReservationExpanded)
    }

    /// One `RoundedRectangle` throughout, not a `Capsule()`/`RoundedRectangle`
    /// switch — swapping between two different `Shape` types (even via
    /// `AnyShape`) cuts instantly instead of morphing, since there's no
    /// single `animatableData` connecting two structurally different
    /// shapes. A huge radius here clamps to min(width, height) / 2 — i.e.
    /// renders as a real capsule — exactly matching the global
    /// `BottomTabBar`'s own shape at rest, and because it's the *same*
    /// `RoundedRectangle` whose `cornerRadius` just changes value, the
    /// `.animation` below smoothly interpolates every intermediate radius
    /// on the way down to the fixed one this grows into for the form,
    /// rather than a hard cut between two disconnected shapes.
    private var reservationBarShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: isReservationExpanded ? AppRadius.r24 : 1000, style: .continuous)
    }

    private var reservationBarBody: some View {
        VStack(spacing: 0) {
            reservationBarContent
            if isReservationExpanded {
                ReservationSheet(pod: pod, liveBedsAvailable: liveBedsAvailable) {
                    isReservationExpanded = false
                }
                // .identity, not the implicit opacity fade a plain `if`
                // gets under an `.animation` — the panel should just be
                // there or not, with only the surrounding VStack's own
                // height change animating, not a separate crossfade on
                // top of it.
                .transition(.identity)
            }
        }
        // On the whole VStack, not just the panel below — so a downward
        // swipe starting anywhere on the expanded bar (including the
        // pod-name row up top) dismisses it, the same way grabbing a
        // real sheet anywhere on its surface would, not only within the
        // form's own drawn content.
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    guard isReservationExpanded else { return }
                    if value.translation.height > 60 {
                        isReservationExpanded = false
                    }
                }
        )
        // Overrides reservationBar's own faster radius animation (it
        // wraps this) for just this height-changing content — the panel
        // growing in should still read as a deliberate reveal at the
        // app's standard pace, not as snappy as the corner resolving.
        .animation(.easeInOut(duration: AppMotion.standard), value: isReservationExpanded)
    }

    private var reservationBarContent: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                // node 3630:955 (checked/"Variant2") — same black-circle-
                // white-check asset as before, but through `.pillStyle()`
                // instead of a bare Circle so it actually picks up the
                // border + drop shadow + white inset-highlight "volume"
                // every other pill/circle button in this app already has,
                // rather than sitting flat. Sized up from the original
                // 20.5pt so it holds its own next to the 17pt pod name
                // instead of reading as an afterthought beside it.
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .pillStyle(fill: .appAccentBlack, border: .appBorder)
                Text(pod.name)
                    .font(AppFont.pillLabelBold(17))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            // Only while collapsed — no separate collapse control once
            // expanded (the form panel below has its own "Confirm
            // reservation" button, and its own scroll/dismiss handles
            // getting back out).
            if !isReservationExpanded {
                Button(action: { isReservationExpanded = true }) {
                    HStack(spacing: 10) {
                        Text("Reserve")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.leading, 24)
                    .padding(.trailing, 20)
                    .padding(.vertical, 10)
                }
                .disabled(!canReserve)
                // node 3850:1250 — shadow is `rgba(200,200,200,0.1)`, a
                // light warm gray, not pillStyle's own default black shadow.
                .pillStyle(
                    fill: canReserve ? .appAccentBlack : .appTextMuted,
                    border: canReserve ? .appBorder : .appTextMuted,
                    shadow: Color(red: 200 / 255, green: 200 / 255, blue: 200 / 255).opacity(0.1)
                )
                // pillStyle's own built-in inset highlight (white 0.25
                // opacity, 1pt blur) is a lot thinner/fainter than
                // Figma's spec here — `inset 2px 5px 4px
                // rgba(230,230,230,0.5)` — which is what's actually
                // giving the button its "volume" (a glossy top sheen
                // reading as real depth). Layering a stronger one on
                // top, scoped to just this button rather than
                // pillStyle's shared default, so nothing else in the
                // app changes.
                .overlay(
                    Capsule()
                        .stroke(Color(red: 230 / 255, green: 230 / 255, blue: 230 / 255).opacity(0.5), lineWidth: 2)
                        .blur(radius: 3)
                        .offset(y: -2)
                        .mask(Capsule())
                )
                // .identity — same fix as the form panel below: a plain
                // `if` under an active `.animation` fades by default,
                // and this button should just vanish the instant the
                // panel opens, not visibly fade out alongside it.
                .transition(.identity)
            }
        }
        // Was a uniform 10 — cramped the checkmark badge right up against
        // the capsule's own stroke. 16/12 (9 vertical while collapsed)
        // gives it real breathing room without ballooning the bar past
        // the global tab bar's own height — the Reserve button's own
        // padding above already dropped from 12 to 10 for the same
        // reason.
        .padding(.horizontal, 16)
        .padding(.vertical, isReservationExpanded ? 12 : 9)
    }

    // MARK: - Prices and bedrooms

    private var pricesSection: some View {
        // 16 — matches every other section's label-to-content gap now
        // that they all share `SectionLabel`.
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: "Prices & bedrooms")

            // Grouped so `.padding(.horizontal, 24)` below applies to
            // whichever of these three is showing, without also wrapping
            // (and re-indenting) `SectionLabel` above — see its own doc
            // comment on why that padding has to stay off the label.
            Group {
                if isLoadingRooms {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 161)
                } else if rooms.isEmpty {
                    // Same 161 as the loading spinner and a real
                    // PodRoomCard — otherwise the section visibly
                    // collapses the instant loading finishes and turns up
                    // empty.
                    Text("No rooms listed yet")
                        .font(AppFont.mediumLabel(16))
                        .foregroundColor(Color.appTextSubtle)
                        .frame(maxWidth: .infinity, minHeight: 161)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(rooms) { room in
                                PodRoomCard(room: room)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, sectionBottomPadding)
        }
    }

    // MARK: - What to expect

    /// Was two separate sections (a payment note buried in
    /// `ReservationSheet`, a standalone "Cancel & reservation changes"
    /// block here) — merged into one, since both are the same kind of
    /// fact: what happens after you tap Reserve, not during it. The
    /// payment line is real, not new copy — same fact `ReservationSheet`
    /// already states ("No payment is taken now — you'll settle up at the
    /// shelter"), just surfaced earlier where a decision is being made
    /// rather than only after reservation's already expanded.
    private var whatToExpectSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: "What to expect")

            // Inter (mediumLabel), not the Darker Grotesque pill-label
            // family — this is a real paragraph of body copy, not a pill
            // label or a large number, the two things Darker Grotesque is
            // meant for per AppFont's own doc comment.
            Text("No payment now — settle up at the shelter. \(cancellationPolicy)")
                .font(AppFont.regularLabel(16))
                .foregroundColor(.appTextMuted)
                .padding(.horizontal, 24)
                .padding(.bottom, sectionBottomPadding)
        }
    }

}

/// Shared visual for the hero's floating circle buttons — factored out so
/// `ShareLink`'s label and `CircleIconButton`'s `Button` label can use the
/// exact same glyph/background/border without duplicating it.
private struct CircleIconGlyph: View {
    let systemName: String
    var tint: Color = .black
    /// Fades the white circle chrome independently of the glyph itself —
    /// used on `topBar`'s back button so its background fades out in sync
    /// with the heart/share pill as the opaque bar fades in behind it.
    var backgroundOpacity: Double = 1

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color.white.opacity(0.9 * backgroundOpacity)))
            .overlay(Circle().strokeBorder(Color.appBorder.opacity(backgroundOpacity), lineWidth: 0.5))
    }
}

private struct CircleIconButton: View {
    let systemName: String
    var tint: Color = .black
    var backgroundOpacity: Double = 1
    let accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIconGlyph(systemName: systemName, tint: tint, backgroundOpacity: backgroundOpacity)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PodRoomCard: View {
    let room: PodRoom

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PodPhoto(url: room.photoURL)

            // Vertical padding matches the map section's address pill (6,
            // not 5) — same role, a translucent caption pill floating on a
            // photo, so they should actually be the same pill.
            Text("\(room.priceMin, specifier: "%.2f")€ - \(room.priceMax, specifier: "%.2f")€")
                .font(AppFont.pillLabelSemiBold(11))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.33)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.75), lineWidth: 0.5))
                .padding(6)
        }
        // Square, not the old 241x161 landscape card — sized down to
        // 161x161, so the loading spinner/empty-state's own 161 minHeight
        // (pricesSection) still matches a real card exactly.
        .frame(width: 161, height: 161)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r10))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.r10).strokeBorder(Color.white.opacity(0.75), lineWidth: 2))
    }
}

// MARK: - Share card

/// The branded card actually shared via `ShareLink` — the pod's photo,
/// name, and location laid out for sharing (Messages, Instagram Stories,
/// saved to Photos, etc.), instead of a plain "name, region, country" text
/// string with a Maps link, which read as unfinished for something meant
/// to represent the app outside itself.
private struct PodShareCard: View {
    let pod: Pod
    let photo: UIImage?

    private let cardSize = CGSize(width: 400, height: 500)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipped()
            } else {
                Rectangle().fill(Color.gray.opacity(0.3))
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )

            if UIImage(named: "podz") != nil {
                Image("podz")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(pod.name)
                    .font(AppFont.pillLabel(32))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let region = pod.region {
                        Text(region)
                        Circle().fill(Color.white.opacity(0.6)).frame(width: 4, height: 4)
                    }
                    Text(pod.country)
                    if let altitude = pod.altitudeM {
                        Circle().fill(Color.white.opacity(0.6)).frame(width: 4, height: 4)
                        Text("\(altitude) m")
                    }
                }
                .font(AppFont.pillLabelMedium(18))
                .foregroundColor(.white.opacity(0.85))
            }
            .padding(28)
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }
}

#Preview {
    PodDetailView(
        pod: Pod(id: UUID(), name: "Rifugio Passo Santner", podType: "Refuge", country: "Italia", region: "Süd Tirol", address: "Passo Santner, Italy", latitude: 46.4589, longitude: 11.6064, altitudeM: 2734, bedsTotal: 40, description: nil),
        onBack: {}
    )
}

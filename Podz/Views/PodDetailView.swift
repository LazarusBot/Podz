//
//  PodDetailView.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

import SwiftUI
import MapKit

/// Reports the hero container's real available width — same background-
/// GeometryReader-plus-preference trick as `PodCard.swift`'s
/// `SectionWidthPreferenceKey` (correct in Slide Over/Split View on iPad,
/// unlike `UIScreen.main.bounds.width`, the full physical screen). Applied
/// to `heroImage`'s own `.background`, not nested inside the TabView or
/// wrapping it — that's the distinction from the *other* GeometryReader
/// approaches tried on this screen and abandoned (see `scrollOffset`'s
/// comment): those read live `.frame(in:)` geometry every frame from
/// *inside* the scrolling/swiping content, fighting its own layout. This
/// one just observes a size from the outside via `.background` and only
/// updates on genuine container resizes (rotation, Split View), not on
/// every swipe frame.
private struct HeroWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = UIScreen.main.bounds.width
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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
    @State private var cameraPosition: MapCameraPosition = .automatic
    @ObservedObject private var likesStore = LikesStore.shared
    @State private var showFolderPicker = false
    @State private var showReservationSheet = false
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
    // Seeded from UIScreen so the very first frame (before
    // HeroWidthPreferenceKey reports back) is still correctly sized
    // rather than starting at 0.
    @State private var heroWidth: CGFloat = UIScreen.main.bounds.width

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
        // Sections are separated by generous whitespace alone now, not a
        // divider line after every one of them — that uniform-line-per-
        // section treatment read as a flat list. Each section supplies its
        // own top padding as the gap from whatever's above it, so the
        // rhythm lives in one place per section instead of being split
        // between a divider's padding and its neighbors'.
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage
                    header
                    hostSection
                    pricesSection
                    cancellationSection
                    mapSection
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

            topBar

            reservationBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .sheet(isPresented: $showReservationSheet) {
            ReservationSheet(pod: pod)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Refreshes the header's live count the moment the sheet closes —
        // a reservation made just now should be reflected immediately,
        // not only the next time this screen happens to reload.
        .onChange(of: showReservationSheet) { _, isShowing in
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
            if let lat = pod.latitude, let lng = pod.longitude {
                // A tilted `.camera` instead of a flat top-down `.region`
                // — realistic elevation (below) only actually reads as 3D
                // terrain relief from an angled viewpoint; straight down,
                // it looks the same as the flat style.
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                        distance: 350,
                        heading: 0,
                        pitch: 60
                    )
                )
            }
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
        heroGallery
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight + heroStretch)
            .clipped()
            .offset(y: -heroStretch)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: HeroWidthPreferenceKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(HeroWidthPreferenceKey.self) { heroWidth = $0 }
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
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                    // Explicit, hard frame per photo — not left to
                    // whatever size the scroll view proposes to each
                    // page. That ambient sizing is what .aspectRatio(.fill)
                    // needs to compute its scale, and it wasn't keeping up
                    // mid-drag during an interactive page transition,
                    // which is what showed up as photos failing to fill
                    // the width specifically while swiping. A concrete
                    // number (heroWidth) is required here, not
                    // .frame(maxWidth: .infinity) — that flexible
                    // constraint turned out to still get renegotiated
                    // mid-drag and let the bug back in. heroWidth itself
                    // comes from HeroWidthPreferenceKey (measured once,
                    // not live), not UIScreen.main.bounds.width, which
                    // breaks in Split View.
                    PodPhoto(url: url)
                        .frame(width: heroWidth, height: heroHeight + heroStretch)
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
        .overlay(alignment: .bottom) {
            // Hand-built page dots — .indexViewStyle came for free with
            // TabView.page; a plain ScrollView has no equivalent, so this
            // replaces it rather than just losing the indicator.
            if heroPhotoURLs.count > 1 {
                HStack(spacing: 6) {
                    ForEach(heroPhotoURLs.indices, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(index == (heroPageIndex ?? 0) ? 1 : 0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.25)))
                .padding(.bottom, 12)
            }
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            // pillLabel is already Darker Grotesque Black — the one text
            // on this screen that's actually meant to be the heaviest
            // weight, so no .fontWeight() needed (it'd be a no-op on a
            // .custom font anyway; see the header/body fixes below).
            Text(pod.name)
                .font(AppFont.pillLabel(24))
                .foregroundColor(.black)

            // 10, not matched to the outer VStack's 10 this time — the
            // pill below is a visually distinct chip (its own capsule
            // background), so it reads better with more separation from
            // the plain region/country text above it, not the same gap.
            // Combined with the pill's own 5pt top padding, that's a 15pt
            // gap total.
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let region = pod.region {
                        Text(region)
                            .font(AppFont.pillLabelMedium(20))
                            .foregroundColor(Color(white: 0.67))
                        Circle().fill(Color(white: 0.67)).frame(width: 4, height: 4)
                    }
                    Text(pod.country)
                        .font(AppFont.pillLabelMedium(20))
                        .foregroundColor(Color(white: 0.67))
                }

                // Two separate pills, not one shared capsule with a dot
                // between them — altitude and bed availability are
                // unrelated facts, not one combined stat.
                if pod.altitudeM != nil || pod.bedsTotal != nil {
                    HStack(spacing: 8) {
                        if let altitude = pod.altitudeM {
                            Text("\(altitude) m")
                                .font(AppFont.pillLabelMedium(16))
                                .foregroundColor(Color(white: 0.67))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color(white: 0.93)))
                        }
                        // Live count when it's loaded (see
                        // `liveBedsAvailable`'s own doc comment) — falls
                        // back to the static total while that's still
                        // loading or if the RPC isn't reachable, so this
                        // pill never just disappears.
                        if let beds = liveBedsAvailable ?? pod.bedsTotal {
                            // Red + "Fully booked" once there's nothing
                            // left, instead of the green "available" pill
                            // just reading "0 beds available" — that read
                            // as a glitch more than a real status.
                            let isFull = beds <= 0
                            let tint = isFull ? Color.red : Color.appAvailableGreen
                            Text(isFull ? "Fully booked" : "\(beds) beds available")
                                .font(AppFont.pillLabelMedium(16))
                                .foregroundColor(tint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(tint.opacity(0.12)))
                                .overlay(alignment: .topTrailing) {
                                    // Stroke matches the page background,
                                    // not the pill's own — punches a clean
                                    // halo around the dot so it reads as
                                    // sitting on top of the pill's corner
                                    // rather than blending into its edge.
                                    Circle()
                                        .fill(tint)
                                        .frame(width: 12, height: 12)
                                        .overlay(Circle().strokeBorder(Color.appHomeBackground, lineWidth: 2))
                                        .offset(x: 2, y: -2)
                                }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: - Host

    /// Title now matches `pricesSection`'s (24pt, full black) — the tier
    /// distinction lives only in spacing now (tight 24pt gap from the
    /// header vs. `pricesSection`'s bigger 36pt gap before it), not in
    /// title size/color anymore.
    private var hostSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Host")
                .font(AppFont.pillLabelBold(24))
                .foregroundColor(.black)

            HStack(spacing: 14) {
                AvatarView(imageName: nil, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hosted by \(hostName)")
                        .font(AppFont.pillLabelBold(17))
                        .foregroundColor(.black)
                    Text(hostBlurb)
                        .font(AppFont.mediumLabel(14))
                        .foregroundColor(.appTextMuted)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    /// Same source as the header's "beds available" pill — while
    /// `liveBedsAvailable` is still loading, falls back to the static
    /// total rather than blocking the button on a number that hasn't
    /// arrived yet.
    private var canReserve: Bool {
        (liveBedsAvailable ?? pod.bedsTotal ?? 1) > 0
    }

    /// node 3850:1245's "Nav Elements" — a whole floating bar of its own,
    /// stacked above the app's global floating tab bar (MainTabView's
    /// `BottomTabBar`), not a button embedded in the scrolling content.
    /// Deliberately a dark glass tint rather than BottomTabBar's white one,
    /// so this bar reads as distinct from the app's global tab bar.
    private var reservationBar: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    reservationBarContent
                        .glassEffect(.regular.tint(.black.opacity(0.1)), in: .capsule)
                }
            } else {
                // Pre-iOS 26 fallback: closest approximation with materials —
                // same as BottomTabBar's own fallback, but dark-tinted.
                reservationBarContent
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().fill(Color.black.opacity(0.1)))
                    )
            }
        }
        .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 0.5))
        .padding(.horizontal, 24)
        .padding(.bottom, 90)
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
                    .foregroundColor(.black)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(action: { showReservationSheet = true }) {
                HStack(spacing: 10) {
                    Text("Reserve")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.leading, 24)
                .padding(.trailing, 20)
                .padding(.vertical, 12)
            }
            .disabled(!canReserve)
            // node 3850:1250 — shadow is `rgba(200,200,200,0.1)`, a
            // light warm gray, not pillStyle's own default black shadow.
            .pillStyle(
                fill: canReserve ? .appAccentBlack : .appTextMuted,
                border: canReserve ? .appBorder : .appTextMuted,
                shadow: Color(red: 200 / 255, green: 200 / 255, blue: 200 / 255).opacity(0.1)
            )
            // pillStyle's own built-in inset highlight (white 0.25 opacity,
            // 1pt blur) is a lot thinner/fainter than Figma's spec here —
            // `inset 2px 5px 4px rgba(230,230,230,0.5)` — which is what's
            // actually giving the button its "volume" (a glossy top sheen
            // reading as real depth). Layering a stronger one on top,
            // scoped to just this button rather than pillStyle's shared
            // default, so nothing else in the app changes.
            .overlay(
                Capsule()
                    .stroke(Color(red: 230 / 255, green: 230 / 255, blue: 230 / 255).opacity(0.5), lineWidth: 2)
                    .blur(radius: 3)
                    .offset(y: -2)
                    .mask(Capsule())
            )
        }
        // Was a uniform 10 — cramped the checkmark badge right up against
        // the capsule's own stroke. 16/12 gives it real breathing room
        // without ballooning the bar's overall height past the Reserve
        // button's own baked-in 12pt vertical padding.
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Prices and bedrooms

    /// Primary section — the one that actually drives the booking
    /// decision, so it gets the bigger/darker title (pillLabelBold 24,
    /// full black) that the two supporting sections below step down from.
    /// 36pt top gap (not 24, like Host got) — this is where the page
    /// shifts from "introducing the place" to the actual booking content.
    private var pricesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // pillLabelBold — not pillLabel(_).fontWeight(.bold), which
            // silently no-ops on a .custom font and rendered this as Black,
            // same weight as the pod name itself.
            Text("Prices and bedrooms")
                .font(AppFont.pillLabelBold(24))
                .foregroundColor(.black)

            if isLoadingRooms {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 161)
            } else if rooms.isEmpty {
                // Same 161 as the loading spinner and a real PodRoomCard —
                // otherwise the section visibly collapses the instant
                // loading finishes and turns up empty.
                Text("No rooms listed yet")
                    .font(AppFont.mediumLabel(16))
                    .foregroundColor(Color(white: 0.67))
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
        .padding(.top, 36)
    }

    // MARK: - Cancellation

    /// Supporting section — one visual step down from `pricesSection`
    /// (smaller title, dark gray instead of full black) since this is
    /// reference info, not the thing driving the booking decision.
    private var cancellationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cancel & reservation changes")
                .font(AppFont.pillLabelBold(19))
                .foregroundColor(.appTextSecondary)

            // Inter (mediumLabel), not the Darker Grotesque pill-label
            // family — this is a real paragraph of body copy, not a pill
            // label or a large number, the two things Darker Grotesque is
            // meant for per AppFont's own doc comment.
            Text(cancellationPolicy)
                .font(AppFont.mediumLabel(16))
                .foregroundColor(.appTextMuted)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
    }

    // MARK: - Map

    /// Supporting section, same demoted tier as `cancellationSection`.
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find us quickly in the wild")
                .font(AppFont.pillLabelBold(19))
                .foregroundColor(Color(white: 0.35))

            ZStack(alignment: .top) {
                if let lat = pod.latitude, let lng = pod.longitude {
                    // interactionModes: [] — this Map sits inside a
                    // vertical ScrollView, so its own pan/pinch would
                    // otherwise fight the page scroll. Tapping it opens
                    // the real, interactive map in Apple Maps instead.
                    // No Marker/Annotation — this close in, at this pitch,
                    // the shelter itself is already visible in the 3D
                    // terrain, so a pin pointing at it is redundant.
                    Map(position: $cameraPosition, interactionModes: [])
                    .mapStyle(.standard(elevation: .realistic))
                    .onTapGesture { openInMaps(lat: lat, lng: lng) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Open \(pod.name) location in Maps")
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }

                if let address = pod.address {
                    Text(address)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.88)))
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 283)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white, lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 24)
    }

    private func openInMaps(lat: Double, lng: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = pod.name
        mapItem.openInMaps()
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
        .frame(width: 241, height: 161)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.75), lineWidth: 2))
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

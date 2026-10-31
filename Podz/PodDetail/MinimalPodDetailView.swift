import SwiftUI

/// The minimalist pod detail (Paper "DetailView" frames).
///
/// **Stack:** a tall photo you swipe through (its pager dots fan out above
/// Lenny's badge), the pod's name and altitude, a two-line teaser and the
/// back / Book pills.
/// **Extended:** tap anywhere between the photo and the buttons and the
/// photo shrinks to make room for the full description and the pod's
/// details; tap again to go back. Paging through the photos is the only
/// swipe on this screen.
struct MinimalPodDetailView: View {
    let pod: Pod
    var onBack: () -> Void

    @State private var photoURLs: [String]
    /// Author and licence of each photo that has one (Wikimedia Commons), by url.
    @State private var photoCredits: [String: String] = [:]
    /// Optional — `.scrollPosition(id:)` needs it.
    @State private var pageIndex: Int? = 0
    @State private var liveBedsAvailable: Int?
    @State private var isExtended = false
    @State private var showBooking = false
    @State private var showHutContact = false
    @State private var showFolderPicker = false
    @ObservedObject private var likesStore = LikesStore.shared

    /// Seeded from the Home card's already-fetched photo so the first frame
    /// isn't empty; the full ordered set arrives from `photos(forPodId:)`.
    init(pod: Pod, onBack: @escaping () -> Void) {
        self.pod = pod
        self.onBack = onBack
        let seed = PodsStore.shared.primaryPhotoByPodId[pod.id]
        _photoURLs = State(initialValue: seed.map { [$0] } ?? [])
    }

    var body: some View {
        GeometryReader { proxy in
            // The whole screen: this view ignores every safe area.
            let screenHeight = proxy.size.height

            let stackPhotoHeight = DetailLayout.podPhotoHeight(screenHeight: screenHeight)

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        if isExtended {
                            // The sections take the screen under a header that
                            // leaves room for the thumbnail. Tap it to go back.
                            extendedHeader
                                .transition(Self.fadeIn)
                            PodDetailSections(pod: pod, liveBedsAvailable: liveBedsAvailable, photoCredit: currentPhotoCredit)
                                .transition(Self.fadeIn)
                        } else {
                            // Room for the photo, which is drawn on top of the
                            // content so it can shrink into the thumbnail.
                            Color.clear.frame(height: stackPhotoHeight)

                            // Everything between the photo and the buttons is one
                            // tap target: a tap anywhere here opens the sections.
                            VStack(spacing: 0) {
                                titleBlock
                                keyFacts
                                stackChips
                                teaser
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { toggleExtended() }
                            .transition(Self.fadeIn)

                            // The buttons float over the page: keep their room.
                            Color.clear.frame(height: 83 + 24 + DetailLayout.controlStackGap + ScreenInsets.bottom)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    // The sections scroll behind the buttons, into the ground.
                    if isExtended {
                        BottomFade()
                            .transition(.opacity)
                    }

                    actionRow
                        .controlStackPadding()
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                // One photo that is both: the big one with the rounded bottom
                // and Lenny's badge, and the small rounded one beside the name.
                // Its size, corners and place animate between the two.
                DetailPhotoPager(
                    slots: photoURLs.map { Optional($0) },
                    pageIndex: $pageIndex,
                    width: isExtended ? Self.thumbnailSize : proxy.size.width,
                    height: isExtended ? Self.thumbnailSize : stackPhotoHeight,
                    coordinate: pod.coordinate,
                    topRadius: isExtended ? Self.thumbnailRadius : 0,
                    bottomRadius: isExtended ? Self.thumbnailRadius : 75,
                    showsBadge: !isExtended
                )
                .scrollDisabled(isExtended)
                .padding(.leading, isExtended ? 24 : 0)
                .padding(.top, isExtended ? Self.thumbnailTop : 0)
                .onTapGesture { if isExtended { toggleExtended() } }
            }
        }
        .ignoresSafeArea()
        .background(Color.homeBackground.ignoresSafeArea())
        // Back is the only way out. The zoom transition's own swipe-to-
        // dismiss fought with paging through the photos.
        .interactiveDismissDisabled()
        .hutContactDialog(for: pod, isPresented: $showHutContact)
        .sheet(isPresented: $showBooking) {
            ReservationSheet(pod: pod, liveBedsAvailable: liveBedsAvailable) { showBooking = false }
                .background(Color.appHomeBackground)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .preferredColorScheme(.light)
        }
        .task {
            async let photos = PodsStore.shared.photoRows(forPodId: pod.id)
            async let beds = pod.isBookable ? PodsStore.shared.bedsAvailableNow(forPodId: pod.id) : nil
            let (fetchedRows, fetchedBeds) = await (photos, beds)
            if !fetchedRows.isEmpty {
                photoURLs = fetchedRows.map(\.url)
                photoCredits = Dictionary(fetchedRows.compactMap { row in row.credit.map { (row.url, $0) } }, uniquingKeysWith: { first, _ in first })
            }
            liveBedsAvailable = fetchedBeds
        }
    }

    // MARK: - Like

    private var isLiked: Bool { likesStore.isLiked(pod) }

    /// A round pill in the action row, same flat style as back and Book.
    /// Unliked, a tap opens the folder picker (the frosted folders and the
    /// photo dropping into one); liked, a tap removes the like.
    private var likeButton: some View {
        DetailRoundButton(
            accessibilityLabel: isLiked ? "Remove from likes" : "Add to likes",
            action: {
                if isLiked {
                    Task { await likesStore.removeLike(pod) }
                } else {
                    showFolderPicker = true
                }
            }
        ) {
            ZStack {
                if isLiked { HeartIconShape().fill(Color.homeText) }
                HeartIconShape()
                    .stroke(Color.homeText.opacity(isLiked ? 1 : 0.45), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 22, height: 22)
            .keyframeAnimator(initialValue: 1.0, trigger: isLiked) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.3, duration: 0.15)
                SpringKeyframe(1.0, spring: .bouncy)
            }
        }
        .likeFolderPicker(for: pod, isPresented: $showFolderPicker)
    }

    // MARK: - Text

    private var titleBlock: some View {
        VStack(spacing: 12) {
            titleText
                .foregroundColor(.homeText)
                .multilineTextAlignment(.center)
            if !pod.isBookable { UnverifiedBadge() }
        }
        .padding(.horizontal, 24)
        .padding(.top, 50)
    }

    private var titleText: Text {
        detailTitle(pod.name, detail: pod.altitudeM.map { "\($0)m" })
    }

    /// "120 beds · 18 free now · Open Jun – Sep": the two facts a traveler
    /// looks for first, under the name.
    private var keyFacts: some View {
        var parts: [String] = []
        if let total = pod.bedsTotal {
            var beds = "\(total) \(total == 1 ? "bed" : "beds")"
            if pod.isBookable, let live = liveBedsAvailable { beds += " · \(live) free now" }
            parts.append(beds)
        }
        if let hours = hutClean(pod.openingHours) { parts.append("Open \(hours)") }
        return Group {
            if !parts.isEmpty {
                Text(parts.joined(separator: "  ·  "))
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.homeText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 14)
                    .padding(.horizontal, 24)
            }
        }
    }

    /// Up to three facilities; the rest are in the sections.
    @ViewBuilder
    private var stackChips: some View {
        if let facilities = pod.facilities, !facilities.isEmpty {
            FacilityChips(facilities: Array(facilities.prefix(3)))
                .padding(.top, 14)
                .padding(.horizontal, 24)
        }
    }

    private var teaser: some View {
        Text(summary)
            .font(AppFont.regularLabel(15))
            .lineSpacing(4)
            .foregroundColor(.homeBodyText)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: 329)
            .padding(.top, 18)
            .padding(.horizontal, 32)
    }

    /// The description if the pod has one, else where it is.
    private var summary: String {
        let description = pod.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return description.isEmpty ? [pod.region, pod.country].compactMap { $0 }.joined(separator: ", ") : description
    }

    // MARK: - Extended header

    private var currentPhotoURL: String? {
        photoURLs.indices.contains(pageIndex ?? 0) ? photoURLs[pageIndex ?? 0] : photoURLs.first
    }

    private var currentPhotoCredit: String? { currentPhotoURL.flatMap { photoCredits[$0] } }

    /// A small photo, the name and altitude and, for a listed hut, the badge.
    private static let thumbnailSize: CGFloat = 92
    private static let thumbnailRadius: CGFloat = 28
    private static let thumbnailTop: CGFloat = 64

    /// The old content leaves quickly, the new arrives a beat later, so the
    /// photo's move is the thing you see.
    private static let fadeIn = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.3).delay(0.18)),
        removal: .opacity.animation(.easeOut(duration: 0.15))
    )

    /// The name and altitude and, for a listed hut, the badge, beside the
    /// thumbnail (which is the photo above, in place).
    private var extendedHeader: some View {
        HStack(spacing: 18) {
            Color.clear.frame(width: Self.thumbnailSize, height: Self.thumbnailSize)

            VStack(alignment: .leading, spacing: 8) {
                Text(pod.name)
                    .font(AppFont.semiBoldLabel(20))
                    .foregroundColor(.homeText)
                    .lineLimit(2)
                if let altitude = pod.altitudeM {
                    Text("\(altitude) m")
                        .font(AppFont.regularLabel(14))
                        .foregroundColor(.homeSubtitle)
                }
                if !pod.isBookable { UnverifiedBadge() }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, Self.thumbnailTop)
        .contentShape(Rectangle())
        .onTapGesture { toggleExtended() }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 13) {
            DetailBackButton(action: onBack)
            likeButton
            if pod.isBookable {
                DetailTextButton(title: "Book") { showBooking = true }
            } else {
                // A listed hut takes its bookings itself.
                DetailTextButton(title: "Book through the hut", isHighlighted: pod.hasContact) { showHutContact = true }
                    .disabled(!pod.hasContact)
                    .opacity(pod.hasContact ? 1 : 0.45)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 24)
    }

    // MARK: - Expand / collapse

    private func toggleExtended() {
        withAnimation(.smooth(duration: 0.45)) { isExtended.toggle() }
    }
}

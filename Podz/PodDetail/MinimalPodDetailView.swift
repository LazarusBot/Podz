import SwiftUI

/// The minimalist pod detail (Paper "DetailView" frames).
///
/// **Stack:** a shorter photo you swipe through (its pager dots fan out above
/// Lenny's badge), the pod's name and altitude, the key facts and facility
/// chips, Lenny's word on the hut (speaking from the badge) and the back /
/// like / Book pills.
/// **Extended:** tap anywhere between the photo and the buttons and the
/// photo shrinks to a thumbnail beside the name; Lenny guides you down the
/// sections (`PodDetailSections`). Tap the header to go back.
struct MinimalPodDetailView: View {
    let pod: Pod
    var onBack: () -> Void

    @State private var photoURLs: [String]
    /// Author and licence of each photo that has one (Wikimedia Commons), by url.
    @State private var photoCredits: [String: String] = [:]
    /// Optional — `.scrollPosition(id:)` needs it.
    @State private var pageIndex: Int? = 0
    /// The section at the top of the extended page: what Lenny talks about.
    @State private var activeSection: PodDetailSection?
    @State private var liveBedsAvailable: Int?
    @State private var isExtended = false
    /// Booking happens right here, with Lenny: the control stack and the
    /// bubble turn into its questions (`BookingFlow`).
    @State private var isBooking = false
    @StateObject private var booking: BookingFlow
    /// The same questions, to add a stay booked through the hut to the list.
    @StateObject private var externalBooking: BookingFlow
    @State private var isExternalFlow = false
    @ObservedObject private var contactTracker = HutContactTracker.shared
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
        _booking = StateObject(wrappedValue: BookingFlow(entries: [Self.bookingEntry(for: pod)]))
        _externalBooking = StateObject(wrappedValue: BookingFlow(entries: [Self.bookingEntry(for: pod)], mode: .external))
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
                            // Lenny walks you down the page, from the top.
                            LennyHutGuide(
                                pod: pod,
                                liveBedsAvailable: liveBedsAvailable,
                                section: activeSection,
                                available: PodDetailSection.available(for: pod, photoCredit: currentPhotoCredit),
                                onGo: { section in withAnimation(.smooth(duration: 0.5)) { activeSection = section } },
                                onContact: { showHutContact = true }
                            )
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .transition(Self.fadeIn)
                            PodDetailSections(pod: pod, liveBedsAvailable: liveBedsAvailable, photoCredit: currentPhotoCredit, active: $activeSection)
                                .transition(Self.fadeIn)
                        } else {
                            // Room for the photo, which is drawn on top of the
                            // content so it can shrink into the thumbnail.
                            Color.clear.frame(height: stackPhotoHeight)

                            // Everything between the photo and the buttons is one
                            // tap target: a tap anywhere here opens the sections.
                            VStack(spacing: 0) {
                                titleBlock
                                if isBooking {
                                    // What's been decided so far, to change on its own.
                                    BookingChips(flow: activeBooking)
                                        .padding(.top, 14)
                                } else {
                                    keyFacts
                                    stackChips
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { if !isBooking { toggleExtended() } }
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

                    // Lenny's bubble sits where it does in Lenny's search and
                    // booking: just above the control stack.
                    if !isExtended {
                        stackLenny
                            .padding(.horizontal, 24)
                            .padding(.bottom, 83 + 20 + DetailLayout.controlStackGap + ScreenInsets.bottom)
                            .transition(Self.fadeIn)
                    }

                    actionRow
                        .controlStackPadding()
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                // One photo that is both: the big one with the rounded bottom
                // and Lenny's badge, and the small rounded one beside the name.
                // Its size, corners and place animate between the two.
                // The pager keeps its full size and is *scaled* down, so its
                // pages never re-layout mid-animation (that made the other
                // photos flash past).
                let thumbScale = Self.thumbnailSize / proxy.size.width
                let scale = isExtended ? thumbScale : 1
                DetailPhotoPager(
                    slots: photoURLs.map { Optional($0) },
                    pageIndex: $pageIndex,
                    width: proxy.size.width,
                    height: stackPhotoHeight,
                    coordinate: pod.coordinate,
                    topRadius: isExtended ? Self.thumbnailRadius / thumbScale : 0,
                    bottomRadius: isExtended ? Self.thumbnailRadius / thumbScale : 75,
                    showsBadge: !isExtended
                )
                .scrollDisabled(isExtended)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width * scale, height: stackPhotoHeight * scale, alignment: .topLeading)
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
        .task {
            async let photos = PodsStore.shared.photoRows(forPodId: pod.id)
            async let beds = pod.isBookable ? PodsStore.shared.bedsAvailableNow(forPodId: pod.id) : nil
            let (fetchedRows, fetchedBeds) = await (photos, beds)
            if !fetchedRows.isEmpty {
                photoURLs = fetchedRows.map(\.url)
                photoCredits = Dictionary(fetchedRows.compactMap { row in row.credit.map { (row.url, $0) } }, uniquingKeysWith: { first, _ in first })
            }
            liveBedsAvailable = fetchedBeds
            booking.liveBedsAvailable = fetchedBeds
        }
        // Back from the hut: the prompt is on the stack, so the page closes.
        .onChange(of: asksIfBooked) { _, asks in
            if asks { withAnimation(.smooth(duration: 0.45)) { isExtended = false } }
        }
        // "Yes" was answered on Home: go straight to the dates.
        .onAppear {
            if contactTracker.accepted, contactTracker.pendingPodId == pod.id, !pod.isBookable { startExternalBooking() }
        }
    }

    /// This pod as the one stop of a Lenny booking.
    private static func bookingEntry(for pod: Pod) -> LennySummaryView.Entry {
        LennySummaryView.Entry(
            stopName: [pod.region, pod.country].compactMap { $0 }.joined(separator: ", "),
            pod: pod,
            detail: "",
            isLennysPick: false
        )
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
            PodStatusRow(pod: pod)
        }
        .padding(.horizontal, 24)
        .padding(.top, 50)
    }

    private var titleText: Text {
        detailTitle(pod.name, detail: pod.altitudeM.map { "\($0)m" })
    }

    /// "120 beds · 18 free now  ·  45 € / night": what a traveler weighs first,
    /// under the name. (Open or closed is the chip above.)
    private var keyFacts: some View {
        var parts: [String] = []
        if let total = pod.bedsTotal {
            var beds = "\(total) \(total == 1 ? "bed" : "beds")"
            if pod.isBookable, let live = liveBedsAvailable { beds += " · \(live) free now" }
            parts.append(beds)
        }
        if let price = pod.priceText {
            parts.append(price)
        } else if !pod.isBookable {
            parts.append("Price at the hut")
        }
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

    /// Lenny's word on the hut, or, while booking, the question: the same
    /// bubble as in Lenny's search, and under it the small caption that says
    /// the page opens.
    @ViewBuilder
    private var stackLenny: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isBooking {
                LennyReply(message: activeBooking.replyMessage, mood: activeBooking.mood)
            } else if asksIfBooked {
                LennyReply(message: "Welcome back! Did you book \(pod.name) with the hut?", mood: .happy)
            } else {
                LennyHutGuide(pod: pod, liveBedsAvailable: liveBedsAvailable, inStack: true)

                Button(action: toggleExtended) {
                    HStack(spacing: 5) {
                        Text("Details")
                            .font(AppFont.regularLabel(13))
                            .foregroundColor(.homeSubtitle)
                            .underline(color: Color.homeSubtitle.opacity(0.5))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.homeSubtitle)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Lined up with the bubble's text, past the avatar.
                .padding(.leading, 38 + 18)
            }
        }
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
                PodStatusRow(pod: pod, isCentered: false)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, Self.thumbnailTop)
        .contentShape(Rectangle())
        .onTapGesture { toggleExtended() }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionRow: some View {
        if isBooking {
            // Lenny's booking controls take the whole row (like and Book step
            // aside until it's done).
            BookingControlStack(
                flow: activeBooking,
                onLeave: leaveBooking,
                onViewReservations: {
                    TabRouter.shared.showsReservationsRequested = true
                    onBack()
                }
            )
            .padding(.horizontal, 40)
            .padding(.top, 24)
        } else if asksIfBooked {
            // Back from the hut: did you book? Yes adds it to your list.
            HStack(spacing: 13) {
                DetailBackButton(action: onBack)
                DetailTextButton(title: "Not yet") { contactTracker.clear() }
                DetailTextButton(title: "Yes, add it", isHighlighted: true, action: startExternalBooking)
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)
        } else {
            HStack(spacing: 13) {
                DetailBackButton(action: onBack)
                likeButton
                if pod.isBookable {
                    DetailTextButton(title: "Book", isHighlighted: true, action: startBooking)
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
    }

    // MARK: - Booking

    private var activeBooking: BookingFlow { isExternalFlow ? externalBooking : booking }

    /// Back from contacting this listed hut, and Lenny hasn't been answered yet.
    private var asksIfBooked: Bool {
        !pod.isBookable && !isBooking && contactTracker.askNow && contactTracker.pendingPodId == pod.id
    }

    /// "Yes, I booked it": the same questions, then the stay goes on the list.
    private func startExternalBooking() {
        contactTracker.clear()
        externalBooking.restart()
        isExternalFlow = true
        withAnimation(.smooth(duration: 0.45)) {
            isExtended = false
            isBooking = true
        }
    }

    /// Book: the page steps back to the stack and Lenny starts asking.
    private func startBooking() {
        isExternalFlow = false
        booking.restart()
        withAnimation(.smooth(duration: 0.45)) {
            isExtended = false
            isBooking = true
        }
    }

    private func leaveBooking() {
        withAnimation(.smooth(duration: 0.35)) { isBooking = false }
        booking.restart()
        externalBooking.restart()
        isExternalFlow = false
    }

    // MARK: - Expand / collapse

    private func toggleExtended() {
        withAnimation(.smooth(duration: 0.45)) { isExtended.toggle() }
    }
}

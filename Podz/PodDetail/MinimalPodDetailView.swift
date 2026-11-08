import SwiftUI

/// The minimalist pod detail (Paper "DetailView" frames).
///
/// **Stack:** a big photo you swipe through with the name, the status chips and
/// the key facts on it (`PodStackCaption`), a "See more" caption, Lenny's word
/// on the hut (`PodStackLenny`) and the back / like / Book pills.
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
    /// Lenny's line on the stack may be said: the zoom has settled and, on a
    /// partner hut, the beds are known, so the line is typed once, the same way
    /// for every hut.
    @State private var guideReady = false
    @State private var isExtended = false
    /// Booking happens right here, with Lenny: the control stack and the
    /// bubble turn into its questions (`BookingFlow`).
    @State private var isBooking = false
    @StateObject private var booking: BookingFlow
    /// The same questions, to add a stay booked through the hut to the list.
    @StateObject private var externalBooking: BookingFlow
    @State private var isExternalFlow = false
    @ObservedObject private var contactTracker = HutContactTracker.shared
    /// Lenny asking how a finished stay went (same card layout).
    @ObservedObject private var feedbackStore = StayFeedbackStore.shared
    @StateObject private var feedback = StayFeedbackFlow()
    @State private var showHutContact = false

    /// Seeded from the Home card's already-fetched photo so the first frame
    /// isn't empty; the full ordered set arrives from `photos(forPodId:)`.
    init(pod: Pod, onBack: @escaping () -> Void) {
        self.pod = pod
        self.onBack = onBack
        // The photos as they were the last time this hut was opened, if it was:
        // the whole set (and so the pager dots) is there from the first frame,
        // the same for every hut. Otherwise the card's own photo.
        let kept = OfflineStorage.load([PodPhotoRow].self, named: "photos-\(pod.id.uuidString)") ?? []
        let seed = PodsStore.shared.primaryPhotoByPodId[pod.id]
        if kept.isEmpty {
            _photoURLs = State(initialValue: seed.map { [$0] } ?? [])
        } else {
            _photoURLs = State(initialValue: kept.map(\.url))
            _photoCredits = State(initialValue: Dictionary(kept.compactMap { row in row.credit.map { (row.url, $0) } }, uniquingKeysWith: { first, _ in first }))
        }
        _booking = StateObject(wrappedValue: BookingFlow(entries: [Self.bookingEntry(for: pod)]))
        _externalBooking = StateObject(wrappedValue: BookingFlow(entries: [Self.bookingEntry(for: pod)], mode: .external))
    }

    var body: some View {
        GeometryReader { proxy in
            // The whole screen: this view ignores every safe area.
            let screenHeight = proxy.size.height

            let stackPhotoHeight = DetailLayout.podPhotoHeight(screenHeight: screenHeight)
            let cardShare = DetailLayout.podCardShare(screenHeight: screenHeight)

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        if isExtended {
                            // The sections take the screen under a header that
                            // leaves room for the thumbnail. Tap it to go back.
                            PodExtendedHeader(pod: pod, onTap: toggleExtended)
                                .transition(Self.fadeIn)
                            // Lenny walks you down the page, from the top.
                            LennyHutGuide(
                                pod: pod,
                                liveBedsAvailable: liveBedsAvailable,
                                section: activeSection,
                                available: PodDetailSection.available(for: pod, photoCredit: currentPhotoCredit, hasKeptPhotos: !feedbackStore.keptPhotos(forPod: pod.id).isEmpty),
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
                            // content so it can shrink into the thumbnail (or
                            // sit as a card, which leaves a little less).
                            Color.clear.frame(height: showsCard ? PodDetailMetrics.thumbnailTop + proxy.size.height * cardShare + 20 : stackPhotoHeight)

                            // Everything between the photo and the buttons is one
                            // tap target: a tap anywhere here opens the sections.
                            VStack(spacing: 0) {
                                // Back from the hut, the page empties: only the
                                // pod's photo and Lenny's question remain.
                                if asksSomething {
                                    EmptyView()
                                } else if isBooking {
                                    // What's been decided so far, to change on its own.
                                    BookingChips(flow: activeBooking, inset: PodDetailMetrics.cardMargin)
                                        .padding(.top, 0)
                                }
                                // (The facilities are in the sections, "On site".)
                                if !asksSomething && !isBooking { PodSeeMoreCaption(action: toggleExtended) }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { if !isBooking && !asksSomething { toggleExtended() } }
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
                        PodStackLenny(
                            pod: pod,
                            liveBedsAvailable: liveBedsAvailable,
                            guideReady: guideReady,
                            isBooking: isBooking,
                            booking: activeBooking,
                            asksHowItWent: asksHowItWent,
                            feedback: feedback,
                            asksIfBooked: asksIfBooked,
                            onNotYet: { contactTracker.clear() }
                        )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 83 + 20 + DetailLayout.controlStackGap + ScreenInsets.bottom)
                            .transition(Self.fadeIn)
                    }

                    actionRow
                        .controlStackPadding()
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                // One photo, three places: the big one with the rounded bottom
                // (the stack), a small rounded one beside the name (the page),
                // and an inset rounded card (back from the hut: only the pod
                // and Lenny's question). Its size, corners and place animate
                // between them. The pager keeps its full size and is *scaled*
                // inside a box that clips it, so its pages never re-layout
                // mid-animation (that made the other photos flash past).
                let width = proxy.size.width
                let thumbScale = PodDetailMetrics.thumbnailSize / width
                let cardWidth = width - 2 * PodDetailMetrics.cardMargin
                let cardHeight = proxy.size.height * cardShare
                // The pager is scaled to fill the card on both sides: with a taller photo
                // the height alone would leave it narrower than the card.
                let cardScale = max(cardHeight / stackPhotoHeight, cardWidth / width)
                let scale: CGFloat = isExtended ? thumbScale : (showsCard ? cardScale : 1)
                let boxWidth: CGFloat = isExtended ? width * thumbScale : (showsCard ? cardWidth : width)
                // The thumbnail is 92 wide and as tall as it was when the stack's photo
                // was 360/852 (84 on this phone), whatever the stack's photo is now.
                let thumbHeight = screenHeight * (360 / 852) * thumbScale
                let boxHeight: CGFloat = isExtended ? thumbHeight : (showsCard ? cardHeight : stackPhotoHeight)
                let topRadius: CGFloat = isExtended ? PodDetailMetrics.thumbnailRadius : (showsCard ? PodDetailMetrics.cardRadius : 0)
                let bottomRadius: CGFloat = isExtended ? PodDetailMetrics.thumbnailRadius : (showsCard ? PodDetailMetrics.cardRadius : 75)
                DetailPhotoPager(
                    slots: photoURLs.map { Optional($0) },
                    pageIndex: $pageIndex,
                    width: width,
                    height: stackPhotoHeight,
                    coordinate: pod.coordinate,
                    topRadius: 0,
                    bottomRadius: 0,
                    showsBadge: !isExtended && !showsCard,
                    dotsAtTop: true
                )
                .scrollDisabled(isExtended || showsCard)
                .scaleEffect(scale, anchor: .center)
                .frame(width: boxWidth, height: boxHeight)
                // In the card the pod keeps its name and altitude, on the flat
                // scrim every photo tile uses.
                .overlay(alignment: .bottomLeading) { PodCardCaption(pod: pod).opacity(showsCard ? 1 : 0) }
                .overlay(alignment: .bottomLeading) {
                    let onStack = !isExtended && !showsCard
                    PodStackCaption(pod: pod, liveBedsAvailable: liveBedsAvailable)
                        .opacity(onStack ? 1 : 0)
                        .allowsHitTesting(onStack)
                }
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: topRadius, bottomLeadingRadius: bottomRadius,
                    bottomTrailingRadius: bottomRadius, topTrailingRadius: topRadius, style: .continuous
                ))
                .padding(.leading, isExtended ? 24 : (showsCard ? PodDetailMetrics.cardMargin : 0))
                .padding(.top, isExtended ? PodDetailMetrics.thumbnailTop : (showsCard ? PodDetailMetrics.thumbnailTop : 0))
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
            // The same beat for every hut: let the opening zoom settle, then (for
            // a partner hut) give the beds up to 0.6 s more to arrive.
            try? await Task.sleep(for: .milliseconds(450))
            var waited = 0
            while pod.isBookable && liveBedsAvailable == nil && waited < 600 {
                try? await Task.sleep(for: .milliseconds(50))
                waited += 50
            }
            guideReady = true
        }
        .task {
            Analytics.shared.track(.podOpened, ["pod_id": pod.id.uuidString, "kind": pod.isBookable ? "partner" : "listed"])
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
        // Back from the hut, something changed: the bubble and the pills
        // spring in, with a tap.
        .animation(.smooth(duration: 0.6), value: asksIfBooked)
        .sensoryFeedback(.impact(weight: .medium), trigger: asksIfBooked) { _, asks in asks }
        .animation(.smooth(duration: 0.6), value: asksHowItWent)
        .sensoryFeedback(.impact(weight: .medium), trigger: asksHowItWent) { _, asks in asks }
        .onChange(of: asksHowItWent) { _, asks in
            guard asks else { return }
            feedback.restart()
            withAnimation(.smooth(duration: 0.45)) { isExtended = false }
        }
        // Back from the hut: the prompt is on the stack, so the page closes.
        .onChange(of: asksIfBooked) { _, asks in
            if asks { withAnimation(.smooth(duration: 0.45)) { isExtended = false } }
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

    // MARK: - State

    private var currentPhotoURL: String? {
        photoURLs.indices.contains(pageIndex ?? 0) ? photoURLs[pageIndex ?? 0] : photoURLs.first
    }

    private var currentPhotoCredit: String? { currentPhotoURL.flatMap { photoCredits[$0] } }

    /// The prompt's layout, and the booking's, in the app or through the hut: the
    /// photo as a card, nothing else but Lenny, so the whole moment looks the same
    /// from the question to "Booked!".
    private var showsCard: Bool { (asksSomething || isBooking) && !isExtended }

    /// Lenny has a question on the page (back from the hut, or the stay is over).
    private var asksSomething: Bool { asksIfBooked || asksHowItWent }

    /// This hut's stay has ended and Lenny asks how it went.
    private var asksHowItWent: Bool {
        !isBooking && !asksIfBooked && feedbackStore.askNow && feedbackStore.pendingStay?.podId == pod.id
    }

    /// The old content leaves quickly, the new arrives a beat later, so the
    /// photo's move is the thing you see.
    private static let fadeIn = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.3).delay(0.18)),
        removal: .opacity.animation(.easeOut(duration: 0.15))
    )

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
            .padding(.horizontal, PodDetailMetrics.cardMargin)
            .padding(.top, 24)
        } else if asksHowItWent {
            // The stay is over: how did it go. Leaving counts as "not now".
            StayFeedbackControls(
                flow: feedback,
                onLeave: { feedback.skip(); onBack() },
                onViewReservations: {
                    TabRouter.shared.showsReservationsRequested = true
                    feedback.finish()
                    onBack()
                }
            )
            .padding(.horizontal, PodDetailMetrics.cardMargin)
            .padding(.top, 24)
            .transition(.risesIn(after: 0.45))
        } else if asksIfBooked {
            // Back from the hut: one answer to give. (Not yet is a caption under
            // Lenny's question.)
            HStack(spacing: 13) {
                // Leaving without answering counts as "not yet": no stale prompt later.
                DetailBackButton { contactTracker.clear(); onBack() }
                DetailTextButton(title: "Yes, I booked it", isHighlighted: true, action: startExternalBooking)
            }
            .padding(.horizontal, PodDetailMetrics.cardMargin)
            .padding(.top, 24)
            .transition(.asymmetric(
                insertion: AnyTransition.move(edge: .bottom).combined(with: .opacity)
                    .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.45)),
                removal: .opacity
            ))
        } else {
            HStack(spacing: 13) {
                DetailBackButton(action: onBack)
                PodLikeButton(pod: pod)
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
        Analytics.shared.track(.externalBookingStarted)
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
        Analytics.shared.track(.bookTapped)
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

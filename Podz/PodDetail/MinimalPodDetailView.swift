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
            let photoHeight = DetailLayout.photoHeight(screenHeight: screenHeight, isExtended: isExtended)

            VStack(spacing: 0) {
                DetailPhotoPager(slots: photoURLs.map { Optional($0) }, pageIndex: $pageIndex, width: proxy.size.width, height: photoHeight)

                // Everything between the photo and the buttons is one tap
                // target: a tap anywhere here extends or collapses.
                VStack(spacing: 0) {
                    titleBlock

                    if isExtended {
                        details
                            .transition(.opacity)
                    } else {
                        teaser
                            .transition(.opacity)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { toggleExtended() }

                actionRow
                    .controlStackPadding()
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
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
            async let photos = PodsStore.shared.photos(forPodId: pod.id)
            async let beds = pod.isBookable ? PodsStore.shared.bedsAvailableNow(forPodId: pod.id) : nil
            let (fetchedPhotos, fetchedBeds) = await (photos, beds)
            if !fetchedPhotos.isEmpty { photoURLs = fetchedPhotos }
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

    private var teaser: some View {
        Text(summary)
            .font(AppFont.regularLabel(16))
            .lineSpacing(5)
            .foregroundColor(.homeBodyText)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: 329)
            .padding(.top, 23)
            .padding(.horizontal, 32)
    }

    /// The description if the pod has one, else where it is.
    private var summary: String {
        let description = pod.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return description.isEmpty ? [pod.region, pod.country].compactMap { $0 }.joined(separator: ", ") : description
    }

    private var details: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(summary)
                    .font(AppFont.regularLabel(16))
                    .lineSpacing(5)
                    .foregroundColor(.homeBodyText)
                    .multilineTextAlignment(.center)

                onSite

                VStack(spacing: 6) {
                    ForEach(facts, id: \.self) { fact in
                        Text(fact)
                            .font(AppFont.regularLabel(14))
                            .foregroundColor(.homeSubtitle)
                    }
                }
            }
            .frame(maxWidth: 329)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    /// What the hut has on site. A listed hut with nothing known says so and
    /// sends the traveler to the hut, rather than leaving a gap.
    @ViewBuilder
    private var onSite: some View {
        if let facilities = pod.facilities, !facilities.isEmpty {
            VStack(spacing: 12) {
                Text("On site")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                FacilityChips(facilities: facilities)
            }
        } else if !pod.isBookable {
            Text("Facilities aren't listed. Ask the hut before you go.")
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
                .multilineTextAlignment(.center)
        }
    }

    private var facts: [String] {
        var lines = [[pod.region, pod.country].compactMap { $0 }.joined(separator: " · ")]
        if !pod.podType.isEmpty { lines.append(pod.podType.capitalized) }
        if let total = pod.bedsTotal {
            var beds = "\(total) \(total == 1 ? "bed" : "beds")"
            if pod.isBookable, let live = liveBedsAvailable { beds += " · \(live) free now" }
            lines.append(beds)
        }
        if let altitude = pod.altitudeM { lines.append("\(altitude) m altitude") }
        if let address = pod.address, !address.isEmpty { lines.append(address) }
        if !pod.isBookable {
            if let hours = pod.openingHours, !hours.isEmpty { lines.append("Open: \(hours)") }
            lines.append("Listed hut: book through the hut")
            if pod.source == "osm" {
                lines.append("Information © OpenStreetMap contributors, not checked by Podz")
            }
        }
        return lines.filter { !$0.isEmpty }
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

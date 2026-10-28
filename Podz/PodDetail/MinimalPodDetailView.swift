import SwiftUI

/// The minimalist pod detail (Paper "DetailView" frames).
///
/// **Stack:** a tall photo you swipe through (its pager dots fan out above
/// Lenny's badge), the pod's name and altitude, a two-line teaser and the
/// back / Book pills.
/// **Extended:** swipe up on the photo or title (or tap the title) and the
/// photo shrinks to make room for the full description and the pod's
/// details; swipe down or tap again to go back.
struct MinimalPodDetailView: View {
    let pod: Pod
    var onBack: () -> Void

    @State private var photoURLs: [String]
    /// Optional — `.scrollPosition(id:)` needs it.
    @State private var pageIndex: Int? = 0
    @State private var liveBedsAvailable: Int?
    @State private var isExtended = false
    @State private var showBooking = false
    @State private var showFolderPicker = false
    @ObservedObject private var likesStore = LikesStore.shared

    /// Photo heights from the Paper frames, as a share of the screen.
    private static let stackedPhotoShare: CGFloat = 524 / 852
    private static let extendedPhotoShare: CGFloat = 250 / 852

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
            let screenHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let photoHeight = screenHeight * (isExtended ? Self.extendedPhotoShare : Self.stackedPhotoShare)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    photoPager(width: proxy.size.width, height: photoHeight)
                    titleBlock
                }
                .contentShape(Rectangle())
                .simultaneousGesture(expandGesture)

                if isExtended {
                    details
                        .transition(.opacity)
                } else {
                    teaser
                        .transition(.opacity)
                    Spacer(minLength: 0)
                }

                actionRow
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 40)
            }
            .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.top)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.homeBackground.ignoresSafeArea())
        .sheet(isPresented: $showBooking) {
            ReservationSheet(pod: pod, liveBedsAvailable: liveBedsAvailable) { showBooking = false }
                .background(Color.appHomeBackground)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .preferredColorScheme(.light)
        }
        .task {
            async let photos = PodsStore.shared.photos(forPodId: pod.id)
            async let beds = PodsStore.shared.bedsAvailableNow(forPodId: pod.id)
            let (fetchedPhotos, fetchedBeds) = await (photos, beds)
            if !fetchedPhotos.isEmpty { photoURLs = fetchedPhotos }
            liveBedsAvailable = fetchedBeds
        }
    }

    // MARK: - Photo

    private func photoPager(width: CGFloat, height: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(Array(pagerURLs.enumerated()), id: \.offset) { index, url in
                    PodPhoto(url: url)
                        .frame(width: width, height: height)
                        .clipped()
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageIndex)
        .frame(width: width, height: height)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 75, bottomTrailingRadius: 75, style: .continuous))
        .overlay(alignment: .bottom) {
            PodDetailBadge(photoCount: photoURLs.count, currentIndex: pageIndex ?? 0)
                .offset(y: 28)
        }
        .zIndex(1)
    }

    /// One empty slot when there are no photos yet, so the pager still
    /// shows the placeholder.
    private var pagerURLs: [String?] {
        photoURLs.isEmpty ? [nil] : photoURLs.map { Optional($0) }
    }

    // MARK: - Like

    private var isLiked: Bool { likesStore.isLiked(pod) }

    /// A round pill in the action row, same flat style as back and Book.
    /// Unliked, a tap opens the folder picker (the frosted folders and the
    /// photo dropping into one); liked, a tap removes the like.
    private var likeButton: some View {
        Button {
            if isLiked {
                Task { await likesStore.removeLike(pod) }
            } else {
                showFolderPicker = true
            }
        } label: {
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
            .frame(width: 83, height: 83)
            .background(pill)
        }
        .buttonStyle(TapScaleButtonStyle())
        .likeFolderPicker(for: pod, isPresented: $showFolderPicker)
        .accessibilityLabel(isLiked ? "Remove from likes" : "Add to likes")
    }

    // MARK: - Text

    private var titleBlock: some View {
        titleText
            .foregroundColor(.homeText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 50)
            .contentShape(Rectangle())
            .onTapGesture { toggleExtended() }
    }

    private var titleText: Text {
        let name = Text(pod.name).font(AppFont.semiBoldLabel(20))
        guard let altitude = pod.altitudeM else { return name }
        let altitudeText = Text("  -  \(altitude)m").font(AppFont.semiBoldLabel(14))
        return Text("\(name)\(altitudeText)")
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

    private var facts: [String] {
        var lines = [[pod.region, pod.country].compactMap { $0 }.joined(separator: " · ")]
        if !pod.podType.isEmpty { lines.append(pod.podType.capitalized) }
        if let total = pod.bedsTotal {
            var beds = "\(total) \(total == 1 ? "bed" : "beds")"
            if let live = liveBedsAvailable { beds += " · \(live) free now" }
            lines.append(beds)
        }
        if let altitude = pod.altitudeM { lines.append("\(altitude) m altitude") }
        if let address = pod.address, !address.isEmpty { lines.append(address) }
        return lines.filter { !$0.isEmpty }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 13) {
            Button(action: onBack) {
                BackChevron()
                    .stroke(Color.homeText.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 8, height: 12)
                    .frame(width: 83, height: 83)
                    .background(pill)
            }
            .buttonStyle(TapScaleButtonStyle())
            .accessibilityLabel("Back")

            likeButton

            Button { showBooking = true } label: {
                Text("Book")
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.homeText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 83)
                    .background(pill)
            }
            .buttonStyle(TapScaleButtonStyle())
        }
        .padding(.horizontal, 40)
        .padding(.top, 24)
    }

    private var pill: some View {
        Capsule()
            .fill(Color.homePill.opacity(0.95))
            .overlay(Capsule().strokeBorder(Color.homeBackground, lineWidth: 1))
    }

    // MARK: - Expand / collapse

    private func toggleExtended() {
        withAnimation(.smooth(duration: 0.45)) { isExtended.toggle() }
    }

    /// Mostly-vertical swipes only, so paging through photos is untouched.
    private var expandGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let vertical = value.translation.height
                guard abs(vertical) > abs(value.translation.width) * 1.5 else { return }
                let wantsExtended = vertical < 0
                guard wantsExtended != isExtended else { return }
                withAnimation(.smooth(duration: 0.45)) { isExtended = wantsExtended }
            }
    }
}

/// The back pill's "<" glyph from the Paper frames (8x12).
private struct BackChevron: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.125))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.1875, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.875))
        return path
    }
}

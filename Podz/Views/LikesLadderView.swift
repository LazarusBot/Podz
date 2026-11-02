import SwiftUI

/// The Likes page as a ladder: one fixed rail that always spans the same
/// heights, from the lowest hut in the app up to the highest one, and it's long:
/// a metre is a point, so it takes several screens to climb it. Your liked huts
/// sit on it at their real altitude, the same size whether you've liked two
/// huts or twenty. It opens on your highest hut. Round photos on the rail, a
/// name and a height beside each, a fade at the bottom. Nothing else.
struct LikesLadderView: View {
    let pods: [Pod]
    let photoURLs: [UUID: String]
    var onOpen: (Pod) -> Void
    /// The folders (the foam) live behind a caption.
    var onFolders: () -> Void

    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var scrollState = ScrollTrackingState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private struct Rung: Identifiable {
        let pod: Pod
        /// Where its altitude falls on the rail.
        let trueY: CGFloat
        /// Where its photo sits (pushed down a little when two huts are close).
        let y: CGFloat
        var id: UUID { pod.id }
    }

    private let headerHeight: CGFloat = 80
    private let railX: CGFloat = 52
    private let photoSize: CGFloat = 60
    /// A point per metre: the rail is thousands of points long.
    private let pointsPerMetre: CGFloat = 1
    /// Closest two photos may sit.
    private let minGap: CGFloat = 72
    /// Under the rail: room for the tab bar.
    private let bottomRoom: CGFloat = 130

    // MARK: - The scale

    /// The rail's heights: the lowest hut in the app (rounded down to 500 m) up
    /// to the highest. A hut above 6,000 m is a typo and is ignored.
    private var scale: (low: Int, high: Int) {
        let heights = podsStore.pods.compactMap(\.altitudeM).filter { $0 > 0 && $0 < 6000 }
        let high = heights.max() ?? 3000
        let low = (heights.min() ?? 0) / 500 * 500
        return (min(low, high - 500), high)
    }

    /// The rail's length: always the same, whatever's liked.
    private var railLength: CGFloat {
        let (low, high) = scale
        return CGFloat(high - low) * pointsPerMetre + 2 * 26
    }

    private func rungs(height: CGFloat) -> [Rung] {
        let (low, high) = scale
        let span = CGFloat(max(high - low, 1))
        let top: CGFloat = 26
        let usable = height - top * 2
        let known = pods.filter { ($0.altitudeM ?? 0) > 0 }
            .sorted { ($0.altitudeM ?? 0) > ($1.altitudeM ?? 0) }
        var result: [Rung] = []
        var lastY = -CGFloat.infinity
        for pod in known {
            let altitude = CGFloat(min(max(pod.altitudeM ?? low, low), high))
            let trueY = top + (1 - (altitude - CGFloat(low)) / span) * usable
            let y = max(trueY, lastY + minGap)
            result.append(Rung(pod: pod, trueY: trueY, y: y))
            lastY = y
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let railHeight = max(railLength, proxy.size.height)
            let placed = rungs(height: railHeight)
            // If many huts crowd the rail, it grows past the screen instead of
            // overlapping them.
            let contentHeight = max(railHeight, (placed.last?.y ?? 0) + photoSize + 40)

            ZStack(alignment: .bottom) {
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            header.frame(height: headerHeight, alignment: .top)

                            ZStack(alignment: .topLeading) {
                                rail(height: railHeight)
                                ForEach(Array(placed.enumerated()), id: \.element.id) { index, rung in
                                    row(rung, index: index).id(rung.id)
                                }
                            }
                            .frame(height: contentHeight, alignment: .topLeading)
                        }
                        Color.clear.frame(height: bottomRoom)
                    }
                    .scrollIndicators(.hidden)
                    // It opens on your highest hut, not on the empty summit.
                    .onAppear {
                        guard let first = placed.first else { return }
                        DispatchQueue.main.async { reader.scrollTo(first.id, anchor: UnitPoint(x: 0.5, y: 0.3)) }
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                    scrollState.updateOffset(offset)
                }

                // The app's own fade into the ground, under the tab bar.
                BottomFade()
                    .frame(height: 260)
                    .allowsHitTesting(false)
            }
            .background(Color.homeBackground)
        }
        .onAppear {
            scrollState.reset()
            withAnimation(.smooth(duration: 0.6)) { appeared = true }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Likes")
                .font(AppFont.semiBoldLabel(30))
                .tracking(-0.6)
                .foregroundColor(.homeText)
            Spacer()
            Button(action: onFolders) {
                HStack(spacing: 5) {
                    Text("Folders")
                        .underline(color: Color.homeSubtitle.opacity(0.5))
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                }
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 25)
    }

    /// The rail, with the app's highest altitude at its top and the lowest at its
    /// foot, so the scale is always the same.
    private func rail(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.homeText.opacity(0.14))
                .frame(width: 1, height: height - 52)
                .offset(x: railX, y: 26)
            Text(Self.metres(scale.high))
                .font(AppFont.regularLabel(11))
                .foregroundColor(.homeSubtitle)
                .offset(x: railX - 40, y: 2)
            Text(Self.metres(scale.low))
                .font(AppFont.regularLabel(11))
                .foregroundColor(.homeSubtitle)
                .offset(x: railX - 40, y: height - 22)
        }
    }

    private static func metres(_ value: Int) -> String {
        "\(value.formatted(.number.grouping(.automatic))) m"
    }

    /// One hut: a small dash on the rail at its real altitude, its round photo
    /// on the rail, the name and the height beside it.
    private func row(_ rung: Rung, index: Int) -> some View {
        let shown = appeared || reduceMotion
        let delay = 0.05 * Double(min(index, 8))
        return Button { onOpen(rung.pod) } label: {
            HStack(spacing: 14) {
                photo(rung.pod)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rung.pod.name)
                        .font(AppFont.semiBoldLabel(15))
                        .foregroundColor(.homeText)
                        .lineLimit(1)
                    Text(Self.metres(rung.pod.altitudeM ?? 0))
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, railX - photoSize / 2)
            .padding(.trailing, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(y: rung.y - photoSize / 2 + (shown ? 0 : 14))
        .opacity(shown ? 1 : 0)
        .animation(.smooth(duration: 0.6).delay(delay), value: appeared)
        .background(alignment: .topLeading) {
            // Where the altitude really is, when the photo had to move aside.
            if abs(rung.y - rung.trueY) > 4 {
                Rectangle()
                    .fill(Color.homeText.opacity(0.35))
                    .frame(width: 10, height: 1)
                    .offset(x: railX - 5, y: rung.trueY - (rung.y - photoSize / 2))
            }
        }
    }

    private func photo(_ pod: Pod) -> some View {
        let picture = PodPhoto(url: photoURLs[pod.id], coordinate: pod.coordinate)
        return Color.clear
            .frame(width: photoSize, height: photoSize)
            .overlay { picture.allowsHitTesting(false) }
            .clipShape(Circle())
            // The ground around it, so the rail reads as passing behind.
            .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 3))
    }
}

import SwiftUI

/// The Likes page as a ladder: your liked huts on one rail, the highest at the
/// top and the lowest at the bottom, spaced by how much higher each one is.
/// Scrolling feels like climbing: a small marker on the rail reads the altitude
/// you're at, and a soft tick marks each hut you pass. Nothing else: a title,
/// a line that says how high it goes, and round photos (the satellite view when
/// there's no photo). The page fades into the ground at both ends.
struct LikesLadderView: View {
    let pods: [Pod]
    let photoURLs: [UUID: String]
    var onOpen: (Pod) -> Void
    /// The folders (the foam) live behind a caption.
    var onFolders: () -> Void

    @StateObject private var scrollState = ScrollTrackingState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var scroll = ScrollSnapshot(offset: 0, viewport: 800)

    private struct ScrollSnapshot: Equatable {
        var offset: CGFloat
        var viewport: CGFloat
    }

    /// One hut on the rail.
    private struct Rung: Identifiable {
        let pod: Pod
        let y: CGFloat
        var id: UUID { pod.id }
    }

    // Layout constants.
    private let headerHeight: CGFloat = 104
    private let railX: CGFloat = 60
    private let photoSize: CGFloat = 84
    private let minGap: CGFloat = 132
    private let maxGap: CGFloat = 250
    private let pointsPerMetre: CGFloat = 0.5
    private let railTop: CGFloat = 28

    // MARK: - The ladder

    /// Highest first. Huts without an altitude go last, after a gap.
    private var rungs: [Rung] {
        let known = pods.filter { $0.altitudeM != nil }.sorted { ($0.altitudeM ?? 0) > ($1.altitudeM ?? 0) }
        let unknown = pods.filter { $0.altitudeM == nil }.sorted { $0.name < $1.name }
        var result: [Rung] = []
        var y = railTop
        for (index, pod) in known.enumerated() {
            if index > 0, let previous = known[index - 1].altitudeM, let current = pod.altitudeM {
                let drop = CGFloat(previous - current) * pointsPerMetre
                y += min(max(drop, minGap), maxGap)
            }
            result.append(Rung(pod: pod, y: y))
        }
        if !unknown.isEmpty {
            y += known.isEmpty ? 0 : maxGap * 0.6
            for (index, pod) in unknown.enumerated() {
                if index > 0 { y += minGap }
                result.append(Rung(pod: pod, y: y))
            }
        }
        return result
    }

    private var knownRungs: [Rung] { rungs.filter { $0.pod.altitudeM != nil } }

    private func railHeight(_ rungs: [Rung]) -> CGFloat { (rungs.last?.y ?? railTop) + photoSize / 2 + 160 }

    /// Altitude to a point on the rail, by interpolating between the huts.
    private func y(forAltitude altitude: Double, in rungs: [Rung]) -> CGFloat? {
        for pair in zip(rungs, rungs.dropFirst()) {
            guard let upper = pair.0.pod.altitudeM.map(Double.init), let lower = pair.1.pod.altitudeM.map(Double.init),
                  altitude <= upper, altitude >= lower, upper > lower else { continue }
            let t = (upper - altitude) / (upper - lower)
            return pair.0.y + CGFloat(t) * (pair.1.y - pair.0.y)
        }
        return nil
    }

    /// A point on the rail back to an altitude.
    private func altitude(atY y: CGFloat, in rungs: [Rung]) -> Int? {
        guard let first = rungs.first, let last = rungs.last,
              let top = first.pod.altitudeM, let bottom = last.pod.altitudeM else { return nil }
        if y <= first.y { return top }
        if y >= last.y { return bottom }
        for pair in zip(rungs, rungs.dropFirst()) where y >= pair.0.y && y <= pair.1.y {
            guard let upper = pair.0.pod.altitudeM, let lower = pair.1.pod.altitudeM, pair.1.y > pair.0.y else { continue }
            let t = Double((y - pair.0.y) / (pair.1.y - pair.0.y))
            return Int((Double(upper) - t * Double(upper - lower)).rounded())
        }
        return nil
    }

    /// Where the viewport's marker sits on the rail.
    private var markerY: CGFloat { scroll.offset + scroll.viewport * 0.42 - headerHeight }

    // MARK: - Body

    var body: some View {
        let all = rungs
        let known = knownRungs
        let height = railHeight(all)

        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .frame(height: headerHeight, alignment: .top)

                    ZStack(alignment: .topLeading) {
                        rail(from: all.first?.y ?? railTop, to: all.last?.y ?? railTop)
                        ticks(known)
                        ForEach(Array(all.enumerated()), id: \.element.id) { index, rung in
                            row(rung, index: index)
                        }
                    }
                    .frame(height: height, alignment: .topLeading)
                }
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: ScrollSnapshot.self) { geometry in
                ScrollSnapshot(offset: geometry.contentOffset.y, viewport: geometry.containerSize.height)
            } action: { _, snapshot in
                scroll = snapshot
                scrollState.updateOffset(snapshot.offset)
            }

            // The soft edge under the title, and the app's fade at the bottom.
            LinearGradient(colors: [.homeBackground, .homeBackground.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
                .allowsHitTesting(false)
            VStack { Spacer(); BottomFade().frame(height: 300) }
                .allowsHitTesting(false)

            marker(known)
        }
        .background(Color.homeBackground)
        .onAppear {
            scrollState.reset()
            withAnimation(.smooth(duration: 0.6)) { appeared = true }
        }
        .sensoryFeedback(.selection, trigger: nearestHutID(known))
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            Text(summary)
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
        }
        .padding(.horizontal, 24)
        .padding(.top, 25)
    }

    /// "12 huts · 1,640 to 3,835 m".
    private var summary: String {
        let heights = pods.compactMap(\.altitudeM)
        let count = "\(pods.count) \(pods.count == 1 ? "hut" : "huts")"
        guard let low = heights.min(), let high = heights.max() else { return count }
        return low == high ? "\(count) · \(Self.metres(high))" : "\(count) · \(Self.metres(low)) to \(Self.metres(high))"
    }

    private static func metres(_ value: Int) -> String {
        "\(value.formatted(.number.grouping(.automatic))) m"
    }

    /// The rail: a hairline from the first hut to the last.
    private func rail(from top: CGFloat, to bottom: CGFloat) -> some View {
        Rectangle()
            .fill(Color.homeText.opacity(0.14))
            .frame(width: 1, height: max(bottom - top, 0))
            .offset(x: railX, y: top)
    }

    /// A tick and its altitude at every 500 m the huts span.
    private func ticks(_ rungs: [Rung]) -> some View {
        let heights = rungs.compactMap { $0.pod.altitudeM }
        return ZStack(alignment: .topLeading) {
            if let low = heights.min(), let high = heights.max(), high - low >= 400 {
                ForEach(Array(stride(from: (low / 500 + 1) * 500, through: high, by: 500)), id: \.self) { level in
                    if let y = y(forAltitude: Double(level), in: rungs) {
                        HStack(spacing: 6) {
                            Text("\(level)")
                                .font(AppFont.regularLabel(10))
                                .foregroundColor(.homeSubtitle)
                                .frame(width: 30, alignment: .trailing)
                            Rectangle().fill(Color.homeText.opacity(0.14)).frame(width: 8, height: 1)
                        }
                        .offset(x: railX - 36, y: y - 6)
                    }
                }
            }
        }
    }

    /// One hut: a dot on the rail, a short rung, the round photo, the name and
    /// the altitude. It rises into place a beat after the one above.
    private func row(_ rung: Rung, index: Int) -> some View {
        let shown = appeared || reduceMotion
        let delay = 0.05 * Double(min(index, 8))
        return Button { onOpen(rung.pod) } label: {
            rowContent(rung)
        }
        .buttonStyle(.plain)
        .offset(y: rung.y - photoSize / 2 + (shown ? 0 : 18))
        .opacity(shown ? 1 : 0)
        .animation(.smooth(duration: 0.6).delay(delay), value: appeared)
    }

    private func rowContent(_ rung: Rung) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: railX - 3, height: 1)
            Circle().fill(Color.homeText).frame(width: 7, height: 7)
            Rectangle().fill(Color.homeText.opacity(0.14)).frame(width: 16, height: 1)
            photoCircle(rung.pod).padding(.leading, 22)
            labels(rung.pod).padding(.leading, 16).padding(.trailing, 24)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func photoCircle(_ pod: Pod) -> some View {
        let photo = PodPhoto(url: photoURLs[pod.id], coordinate: pod.coordinate)
        return Color.clear
            .frame(width: photoSize, height: photoSize)
            .overlay { photo.allowsHitTesting(false) }
            .clipShape(Circle())
    }

    private func labels(_ pod: Pod) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pod.name)
                .font(AppFont.semiBoldLabel(16))
                .foregroundColor(.homeText)
                .lineLimit(2)
            Text(caption(for: pod))
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
                .lineLimit(1)
        }
    }

    private func caption(for pod: Pod) -> String {
        let altitude = pod.altitudeM.map { Self.metres($0) }
        return [altitude, pod.region ?? pod.country].compactMap { $0 }.joined(separator: " · ")
    }

    /// The marker on the rail: the altitude you're at, fixed on the screen.
    @ViewBuilder
    private func marker(_ rungs: [Rung]) -> some View {
        if rungs.count > 1, let level = altitude(atY: markerY, in: rungs) {
            Text(Self.metres(level))
                .font(AppFont.semiBoldLabel(11))
                .foregroundColor(.homeBackground)
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(Capsule().fill(Color.homeText))
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, railX - 30)
                .padding(.top, scroll.viewport * 0.42 - 11)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The hut the marker is next to, for the tick.
    private func nearestHutID(_ rungs: [Rung]) -> UUID? {
        rungs.first { abs($0.y - markerY) < 36 }?.pod.id
    }
}

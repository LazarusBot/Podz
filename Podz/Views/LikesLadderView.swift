import SwiftUI
import Combine

/// The Likes page as a ladder: one fixed rail that always spans the same
/// heights, from the lowest hut in the app up to the highest one, and it's long:
/// a metre is a point, so it takes several screens to climb it.
///
/// Three layers, so it stays smooth: a ruler behind (thin ticks down the right
/// edge, drawn on a canvas, that swell near the reading), the scrolling page
/// with your huts on the rail at their real altitude (a round photo, the name
/// beside it), and in front the **reading**: the altitude you're at, in big
/// type like the title, counting as you swipe. Only the reading and the ruler
/// follow the scroll; the page itself is not redrawn while you swipe.
struct LikesLadderView: View {
    let pods: [Pod]
    let photoURLs: [UUID: String]
    var onOpen: (Pod) -> Void
    /// The folders (the foam) live behind a caption.
    var onFolders: () -> Void

    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var scrollState = ScrollTrackingState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The huts rise in once; coming back from the folders they're just there.
    private static var hasPlayedEntry = false
    @State private var appeared = Self.hasPlayedEntry
    /// Where the page is scrolled. Held, never read here: only the ruler and the
    /// reading watch it, so a swipe doesn't redraw the page.
    @State private var reading = LadderReading()
    @State private var position = ScrollPosition(edge: .top)

    private struct Rung: Identifiable {
        let pod: Pod
        /// Where its altitude falls on the rail.
        let trueY: CGFloat
        /// Where its photo sits (pushed down a little when two huts are close).
        let y: CGFloat
        var id: UUID { pod.id }
    }

    private let headerHeight: CGFloat = 80
    private let photoSize: CGFloat = 60
    /// A point per metre: the rail is thousands of points long.
    private let pointsPerMetre: CGFloat = 1
    /// Closest two photos may sit.
    private let minGap: CGFloat = 72
    /// Under the rail: room for the tab bar.
    private let bottomRoom: CGFloat = 130
    /// Margin above the summit and below the foot of the rail.
    private let railMargin: CGFloat = 26
    /// Where on the screen the reading sits.
    private let readingShare: CGFloat = 0.42

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
        return CGFloat(high - low) * pointsPerMetre + 2 * railMargin
    }

    private func levelY(_ altitude: Int, height: CGFloat) -> CGFloat {
        let (low, high) = scale
        let span = CGFloat(max(high - low, 1))
        return railMargin + (1 - (CGFloat(altitude) - CGFloat(low)) / span) * (height - railMargin * 2)
    }

    private func rungs(height: CGFloat) -> [Rung] {
        let (low, high) = scale
        let known = pods.filter { ($0.altitudeM ?? 0) > 0 }
            .sorted { ($0.altitudeM ?? 0) > ($1.altitudeM ?? 0) }
        var result: [Rung] = []
        var lastY = -CGFloat.infinity
        for pod in known {
            let altitude = min(max(pod.altitudeM ?? low, low), high)
            let trueY = levelY(altitude, height: height)
            let y = max(trueY, lastY + minGap)
            result.append(Rung(pod: pod, trueY: trueY, y: y))
            lastY = y
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let railX = width - 48
            let railHeight = max(railLength, proxy.size.height)
            let placed = rungs(height: railHeight)
            // If many huts crowd the rail, it grows past the screen instead of
            // overlapping them.
            let contentHeight = max(railHeight, (placed.last?.y ?? 0) + photoSize + 40)
            let (low, high) = scale

            ZStack(alignment: .topLeading) {
                // Behind everything: the ruler down the right edge.
                LadderRuler(
                    reading: reading,
                    low: low,
                    high: high,
                    railMargin: railMargin,
                    railHeight: railHeight,
                    headerHeight: headerHeight,
                    railX: railX,
                    readingY: proxy.size.height * readingShare
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header.frame(height: headerHeight, alignment: .top)

                        ZStack(alignment: .topLeading) {
                            railLine(height: railHeight, x: railX, low: low, high: high)
                            ForEach(Array(placed.enumerated()), id: \.element.id) { index, rung in
                                row(rung, index: index, railX: railX, width: width, viewport: proxy.size.height)
                            }
                        }
                        .frame(width: width, height: contentHeight, alignment: .topLeading)
                    }
                    Color.clear.frame(height: bottomRoom)
                }
                .scrollIndicators(.hidden)
                .scrollPosition($position)
                // Each hut is a stop: the swipe comes to rest with it at the reading.
                .scrollTargetBehavior(LadderStopBehavior(
                    stops: placed.map { max(headerHeight + $0.y - proxy.size.height * readingShare, 0) },
                    reading: reading
                ))
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                    reading.offset = offset
                    scrollState.updateOffset(offset)
                }

                // The app's own fade into the ground, under the tab bar.
                VStack {
                    Spacer()
                    BottomFade().frame(height: 260)
                }
                .allowsHitTesting(false)

                // In front: the altitude you're at, big like the title.
                LadderReadingLabel(reading: reading, low: low, high: high, railMargin: railMargin, railHeight: railHeight, headerHeight: headerHeight, viewport: proxy.size.height, readingShare: readingShare)
            }
            .background(Color.homeBackground)
            .onAppear {
                reading.viewport = proxy.size.height
                // It opens on your highest hut, not on the empty summit.
                if let first = placed.first {
                    position.scrollTo(y: max(headerHeight + first.y - proxy.size.height * readingShare, 0))
                }
            }
        }
        .onAppear {
            scrollState.reset()
            if !Self.hasPlayedEntry {
                Self.hasPlayedEntry = true
                withAnimation(.smooth(duration: 0.6)) { appeared = true }
            }
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
    private func railLine(height: CGFloat, x: CGFloat, low: Int, high: Int) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.homeText.opacity(0.12))
                .frame(width: 1, height: height - railMargin * 2)
                .offset(x: x, y: railMargin)
            Text(Self.metres(high))
                .font(AppFont.regularLabel(11))
                .foregroundColor(.homeSubtitle)
                .frame(width: 70, alignment: .trailing)
                .offset(x: x - 80, y: 2)
            Text(Self.metres(low))
                .font(AppFont.regularLabel(11))
                .foregroundColor(.homeSubtitle)
                .frame(width: 70, alignment: .trailing)
                .offset(x: x - 80, y: height - 22)
        }
    }

    static func metres(_ value: Int) -> String {
        "\(value.formatted(.number.grouping(.automatic))) m"
    }

    /// One hut: its round photo on the rail (at the right), the name and the
    /// height to the left of it, right-aligned so the reading has the left side.
    private func row(_ rung: Rung, index: Int, railX: CGFloat, width: CGFloat, viewport: CGFloat) -> some View {
        let shown = appeared || reduceMotion
        let delay = 0.05 * Double(min(index, 8))
        return Button { onOpen(rung.pod) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(rung.pod.name)
                        .font(AppFont.semiBoldLabel(15))
                        .foregroundColor(.homeText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                    Text(Self.metres(rung.pod.altitudeM ?? 0))
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                }
                .frame(maxWidth: 128, alignment: .trailing)
                .modifier(LadderFocus(reading: reading, part: .text, pageY: headerHeight + rung.y, readingY: viewport * readingShare))
                photo(rung.pod)
                    .modifier(LadderFocus(reading: reading, part: .photo, pageY: headerHeight + rung.y, readingY: viewport * readingShare))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The hut at the reading rises above its neighbours.
        .modifier(LadderFocus(reading: reading, part: .row, pageY: headerHeight + rung.y, readingY: viewport * readingShare))
        .padding(.trailing, width - railX - photoSize / 2)
        .frame(width: width, alignment: .trailing)
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

// MARK: - Stopping at a hut

/// Where a swipe comes to rest: at a hut, with it level with the reading. A
/// slower swipe stops at the first hut in its path, so you can't slide past one
/// without seeing it; a hard flick may carry on, and lands on the hut nearest
/// to where it was heading.
private struct LadderStopBehavior: ScrollTargetBehavior {
    /// Scroll offsets at which a hut is level with the reading.
    let stops: [CGFloat]
    let reading: LadderReading

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard !stops.isEmpty else { return }
        let ordered = stops.sorted()
        let current = reading.offset
        let proposed = target.rect.minY
        guard abs(proposed - current) > 4 else { return }
        let goesDown = proposed > current
        let hardFlick = abs(context.velocity.dy) > 1800

        var chosen: CGFloat?
        if !hardFlick {
            // The first hut in the way.
            chosen = goesDown
                ? ordered.first { $0 > current + 6 && $0 <= proposed + 48 }
                : ordered.last { $0 < current - 6 && $0 >= proposed - 48 }
        }
        if chosen == nil, let nearest = ordered.min(by: { abs($0 - proposed) < abs($1 - proposed) }),
           abs(nearest - proposed) < 220 {
            chosen = nearest
        }
        if let chosen { target.rect.origin.y = chosen }
    }
}

// MARK: - Following the scroll

/// A hut at the reading's height grows so you can look at it: its photo to 1.6
/// times as it passes, the name a little, and it comes in front of its
/// neighbours, with a light tap when it lands on the reading. Each piece
/// watches the scroll by itself, so the page isn't redrawn.
private struct LadderFocus: ViewModifier {
    enum Part { case row, photo, text }

    @ObservedObject var reading: LadderReading
    let part: Part
    /// The photo's height on the page (from the top of the content).
    let pageY: CGFloat
    /// The reading's height on the screen.
    let readingY: CGFloat

    /// 0 away from the reading, 1 right on it.
    private var focus: CGFloat {
        let distance = abs(pageY - reading.offset - readingY)
        let t = max(0, 1 - distance / 90)
        return t * t * (3 - 2 * t)   // smoothstep
    }

    func body(content: Content) -> some View {
        let t = focus
        switch part {
        case .row:
            content
                .zIndex(Double(t))
                .sensoryFeedback(.impact(weight: .light), trigger: t > 0.85) { _, landed in landed }
        case .photo:
            content.scaleEffect(1 + 0.6 * t)
        case .text:
            // Steps aside as the photo grows (it gains 18 pt each side).
            content.scaleEffect(1 + 0.12 * t, anchor: .trailing).offset(x: -20 * t)
        }
    }
}

/// Where the ladder is scrolled. The ruler and the reading watch it; the page
/// holds it in `@State` without reading it, so it isn't redrawn on a swipe.
final class LadderReading: ObservableObject {
    @Published var offset: CGFloat = 0
    var viewport: CGFloat = 800
}

/// The altitude at a screen height, given where the page is scrolled.
private func altitude(atScreenY y: CGFloat, reading: LadderReading, low: Int, high: Int, railMargin: CGFloat, railHeight: CGFloat, headerHeight: CGFloat) -> Int {
    let contentY = y + reading.offset - headerHeight
    let t = (contentY - railMargin) / max(railHeight - railMargin * 2, 1)
    let altitude = CGFloat(high) - min(max(t, 0), 1) * CGFloat(high - low)
    return Int(altitude.rounded())
}

/// The ruler: thin ticks down the right edge, a longer one every 100 m and the
/// longest every 500 m. They slide with the page, and swell where the reading
/// is, like a dial.
private struct LadderRuler: View {
    @ObservedObject var reading: LadderReading
    let low: Int
    let high: Int
    let railMargin: CGFloat
    let railHeight: CGFloat
    let headerHeight: CGFloat
    let railX: CGFloat
    let readingY: CGFloat

    var body: some View {
        Canvas { context, size in
                let offset = reading.offset
                let span = CGFloat(max(high - low, 1))
                let usable = railHeight - railMargin * 2
                var level = (low / 50 + 1) * 50
                while level < high {
                    let y = headerHeight + railMargin + (1 - (CGFloat(level) - CGFloat(low)) / span) * usable - offset
                    if y > -10 && y < size.height + 10 {
                        let major = level % 500 == 0
                        let medium = level % 100 == 0
                        let base: CGFloat = major ? 16 : (medium ? 10 : 5)
                        // Swells within 110 pt of the reading.
                        let near = max(0, 1 - abs(y - readingY) / 110)
                        let length = base + near * near * 14
                        let opacity = (major ? 0.34 : (medium ? 0.22 : 0.13)) + Double(near) * 0.3
                        var path = Path()
                        path.move(to: CGPoint(x: size.width - 14 - length, y: y))
                        path.addLine(to: CGPoint(x: size.width - 14, y: y))
                        context.stroke(path, with: .color(Color.homeText.opacity(min(opacity, 0.9))), lineWidth: 1)
                    }
                    level += 50
                }
        }
        .allowsHitTesting(false)
    }
}

/// The reading: the altitude at 42% of the screen, big like the title, fixed on
/// the left while the ladder moves under it. A soft click every 100 m.
private struct LadderReadingLabel: View {
    @ObservedObject var reading: LadderReading
    let low: Int
    let high: Int
    let railMargin: CGFloat
    let railHeight: CGFloat
    let headerHeight: CGFloat
    let viewport: CGFloat
    let readingShare: CGFloat

    var body: some View {
        let value = altitude(atScreenY: viewport * readingShare, reading: reading, low: low, high: high, railMargin: railMargin, railHeight: railHeight, headerHeight: headerHeight)
        Text(LikesLadderView.metres(value))
            .font(AppFont.semiBoldLabel(30))
            .tracking(-0.6)
            .monospacedDigit()
            .foregroundColor(.homeText)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 24)
            .padding(.top, viewport * readingShare - 20)
            .sensoryFeedback(.selection, trigger: value / 100)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

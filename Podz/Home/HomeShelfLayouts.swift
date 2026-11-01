import SwiftUI

/// Home's shelves don't all look alike, so the page has a rhythm: the hero
/// carousel (`HomePodCard`), tall cards for the highest pods, and a mosaic for
/// a region. Each takes the same photos, radii and flat scrim as the rest.

// MARK: - Tall: the highest pods

/// A narrow, tall photo with the altitude as a big number on it, the name and
/// region under it.
struct HomeTallCard: View {
    let pod: Pod
    let photoURL: String?
    let zoomNamespace: Namespace.ID
    var zoomID: AnyHashable
    var onTap: () -> Void

    static let width: CGFloat = 156
    static let photoHeight: CGFloat = 236

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Color.clear
                    .frame(width: Self.width, height: Self.photoHeight)
                    // The photo is drawn bigger than its frame: it must not take
                    // taps, or it steals them from the next card.
                    .overlay { PodPhoto(url: photoURL, coordinate: pod.coordinate, pixelWidth: 480).allowsHitTesting(false) }
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 100)
                    }
                    .overlay(alignment: .bottomLeading) {
                        if let altitude = pod.altitudeM {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(altitude)")
                                    .font(AppFont.semiBoldLabel(30))
                                    .tracking(-0.6)
                                Text("m")
                                    .font(AppFont.regularLabel(14))
                            }
                            .foregroundColor(.white)
                            .padding(.leading, 16)
                            .padding(.bottom, 14)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .podZoomSource(id: zoomID, in: zoomNamespace, cornerRadius: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pod.name)
                        .font(AppFont.semiBoldLabel(15))
                        .foregroundColor(.homeText)
                        .lineLimit(1)
                    Text(pod.region ?? pod.country)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
                .frame(width: Self.width, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mosaic: a region

/// One lead photo and two smaller ones, a single block: a region reads as a
/// place. Names sit on the photos on the same flat scrim as every photo tile.
struct HomeMosaic: View {
    /// The lead first, then one or two smaller (a single one takes the whole
    /// side); fewer than two isn't a mosaic.
    let pods: [Pod]
    let photoURLs: [UUID: String]
    let zoomNamespace: Namespace.ID
    var zoomIDPrefix: String
    var onTap: (Pod, AnyHashable) -> Void

    private let gap: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let total = proxy.size.width
            let lead = (total - gap) * 0.57
            let side = total - gap - lead
            let smallHeight = (proxy.size.height - gap) / 2

            HStack(spacing: gap) {
                tile(pods[0], width: lead, height: proxy.size.height, radius: 32, large: true)
                if pods.count >= 3 {
                    VStack(spacing: gap) {
                        tile(pods[1], width: side, height: smallHeight, radius: 26, large: false)
                        tile(pods[2], width: side, height: smallHeight, radius: 26, large: false)
                    }
                } else {
                    tile(pods[1], width: side, height: proxy.size.height, radius: 32, large: false)
                }
            }
        }
        .frame(height: 270)
        .padding(.horizontal, 24)
    }

    private func tile(_ pod: Pod, width: CGFloat, height: CGFloat, radius: CGFloat, large: Bool) -> some View {
        let zoomID = AnyHashable("\(zoomIDPrefix)-\(pod.id)")
        return Button { onTap(pod, zoomID) } label: {
            Color.clear
                .frame(width: width, height: height)
                // The photo is drawn bigger than its tile: it must not take
                // taps, or it steals them from the tile next to it.
                .overlay { PodPhoto(url: photoURLs[pod.id], coordinate: pod.coordinate, pixelWidth: large ? 640 : 480).allowsHitTesting(false) }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        .frame(height: large ? 110 : 70)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pod.name)
                            .font(AppFont.semiBoldLabel(large ? 17 : 13))
                            .lineLimit(large ? 2 : 1)
                        if large, let beds = pod.bedsTotal {
                            Text("\(beds) \(beds == 1 ? "bed" : "beds")")
                                .font(AppFont.regularLabel(13))
                                .opacity(0.85)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, large ? 18 : 14)
                    .padding(.bottom, large ? 18 : 12)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .podZoomSource(id: zoomID, in: zoomNamespace, cornerRadius: radius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pod.name)
    }
}

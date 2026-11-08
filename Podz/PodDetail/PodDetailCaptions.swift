import SwiftUI

/// The measures of the pod detail page, shared by the page and its pieces.
enum PodDetailMetrics {
    /// The extended page's small photo beside the name.
    static let thumbnailSize: CGFloat = 92
    static let thumbnailRadius: CGFloat = 28
    static let thumbnailTop: CGFloat = 64
    /// Back from the hut: the photo is an inset card, 46 from the sides.
    static let cardMargin: CGFloat = 46
    static let cardRadius: CGFloat = 40
    /// The text on the stack's photo, and the caption under it, sit this far from
    /// the left (and the right): the photo's bottom corners are 75 round.
    static let stackCaptionInset: CGFloat = 40
}

/// The name, the status chips and the key facts, **on the photo** at its bottom
/// left, well inside its edges, over a scrim that fades up (the page's one
/// headline), until the page is asked something or opens its sections.
struct PodStackCaption: View {
    let pod: Pod
    let liveBedsAvailable: Int?

    /// "120 beds · 18 free now  ·  45 € / night": what a traveler weighs first.
    /// (Open or closed is the chip above it.)
    private var keyFactsText: String? {
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
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // One line: a long name is cut with an ellipsis so the altitude stays.
            DetailTitleLine(name: pod.name, altitude: pod.altitudeM.map { "\($0)m" }, isCentered: false)
            PodStatusRow(pod: pod, isCentered: false, onPhoto: true)
            if let facts = keyFactsText {
                T(facts)
                    .font(AppFont.regularLabel(14))
                    .opacity(0.92)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .foregroundColor(.onPhoto)
        // Inset like the card's caption, in proportion to the corner: the card
        // has 22 / 20 for a radius of 40, so here (radius 75) 40 / 38 leaves the
        // same gap between the text's corner and the curve (about a third of the
        // radius), and the text reads as following the photo's shape.
        .padding(.horizontal, PodDetailMetrics.stackCaptionInset)
        .padding(.bottom, 38)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .photoScrim.opacity(0.62)], startPoint: .top, endPoint: .bottom)
                .frame(height: 250)
                .allowsHitTesting(false)
        }
    }
}

/// The name and altitude on the card's photo, over a scrim at the bottom.
struct PodCardCaption: View {
    let pod: Pod

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(pod.name)
                .font(AppFont.semiBoldLabel(20))
                .lineLimit(2)
            Text([pod.altitudeM.map { "\($0) m" }, pod.region ?? pod.country].compactMap { $0 }.joined(separator: " \u{00B7} "))
                .font(AppFont.regularLabel(13))
                .opacity(0.85)
        }
        .foregroundColor(.onPhoto)
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .photoScrim.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .frame(height: 130)
        }
    }
}

/// The small caption right under the photo that says where to touch for the
/// page (the whole area down to Lenny opens it too).
struct PodSeeMoreCaption: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CaptionLabel("See more", vertical: 4, outset: 10)
        }
        .buttonStyle(.plain)
        // In line with the text on the photo above it.
        .padding(.leading, PodDetailMetrics.stackCaptionInset)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The name and altitude and, for a listed hut, the badge, beside the
/// thumbnail (which is the photo above, in place). A tap goes back to the stack.
struct PodExtendedHeader: View {
    let pod: Pod
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Color.clear.frame(width: PodDetailMetrics.thumbnailSize, height: PodDetailMetrics.thumbnailSize)

            VStack(alignment: .leading, spacing: 8) {
                Text(pod.name)
                    .font(AppFont.semiBoldLabel(20))
                    .foregroundColor(.homeText)
                    .lineLimit(2)
                if let altitude = pod.altitudeM {
                    T("\(altitude) m")
                        .font(AppFont.regularLabel(14))
                        .foregroundColor(.homeSubtitle)
                }
                PodStatusRow(pod: pod, isCentered: false)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, PodDetailMetrics.thumbnailTop)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

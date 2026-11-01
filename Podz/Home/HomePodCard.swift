import SwiftUI

/// One big card in "Available tonight": rounded photo, then name and a
/// quiet "region · beds" line, straight on the ground — no card chrome.
struct HomePodCard: View {
    let pod: Pod
    let photoURL: String?
    let zoomNamespace: Namespace.ID
    /// Tells apart this card from the same pod's card on another shelf, so the
    /// zoom opens from the one that was tapped. The pod's id by default.
    var zoomID: AnyHashable?
    /// Replaces the default "region · beds" line (the highest shelf says the
    /// altitude, for example).
    var subtitleOverride: String?
    var onTap: () -> Void

    private var subtitle: String {
        if let subtitleOverride { return subtitleOverride }
        var parts = [pod.region ?? pod.country]
        if let beds = pod.bedsTotal {
            parts.append("\(beds) \(beds == 1 ? "bed" : "beds")")
        }
        // A listed hut can't be booked in the app: say so on the card.
        if !pod.isBookable { parts.append("Listed") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Color.clear
                    .aspectRatio(296.0 / 340.0, contentMode: .fit)
                    // The photo is drawn bigger than its frame (it fills it): it
                    // must not take taps, or it steals them from the next card.
                    .overlay { PodPhoto(url: photoURL, coordinate: pod.coordinate, pixelWidth: 900).allowsHitTesting(false) }
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .podZoomSource(id: zoomID ?? AnyHashable(pod.id), in: zoomNamespace, cornerRadius: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pod.name)
                        .font(AppFont.semiBoldLabel(16))
                        .foregroundColor(.homeText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(AppFont.regularLabel(14))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(1)
                }
                .padding(.horizontal, 5)
            }
            // The whole card is the button, gaps included.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

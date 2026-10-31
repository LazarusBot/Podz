import SwiftUI
import MapKit

/// The extended pod detail: what a traveler wants to know before trusting a
/// hut, as quiet sections under a small photo. About, On site, Good to know,
/// Getting there, Contact and, for a listed hut, where the information comes
/// from. Each section is a 13 `homeSubtitle` heading over flat content; rows
/// are 52 high with a hairline.
struct PodDetailSections: View {
    let pod: Pod
    var liveBedsAvailable: Int?
    /// Author and licence of the photo on screen, when it has one.
    var photoCredit: String?
    /// The section at the top of the page, which Lenny talks about; setting
    /// it scrolls there.
    @Binding var active: PodDetailSection?

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                ForEach(PodDetailSection.available(for: pod, photoCredit: photoCredit), id: \.self) { section in
                    view(for: section).id(section)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 24)
            .padding(.top, 28)
            // Room to scroll the last section above Lenny and the buttons.
            .padding(.bottom, 330)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollPosition(id: $active, anchor: .top)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func view(for section: PodDetailSection) -> some View {
        switch section {
        case .about: about
        case .onSite: onSite
        case .goodToKnow: goodToKnow
        case .gettingThere: gettingThere
        case .contact: contact
        case .source: source
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var about: some View {
        if let description = hutClean(pod.description) {
            DetailSection("About") {
                Text(description)
                    .font(AppFont.regularLabel(16))
                    .lineSpacing(5)
                    .foregroundColor(.homeBodyText)
            }
        }
    }

    /// A listed hut with nothing known says so and sends the traveler to the
    /// hut, rather than leaving a gap.
    @ViewBuilder
    private var onSite: some View {
        if let facilities = pod.facilities, !facilities.isEmpty {
            DetailSection("On site") { FacilityChips(facilities: facilities, isCentered: false) }
        } else if !pod.isBookable {
            DetailSection("On site") {
                Text("Facilities aren't listed. Ask the hut before you go.")
                    .font(AppFont.regularLabel(15))
                    .foregroundColor(.homeSubtitle)
            }
        }
    }

    private var goodToKnow: some View {
        DetailSection("Good to know") {
            VStack(spacing: 0) {
                row("Where", [pod.region, pod.country].compactMap { $0 }.joined(separator: ", "))
                row("Type", pod.podType.capitalized)
                row("Altitude", pod.altitudeM.map { "\($0) m" })
                row("Beds", bedsText)
                row("Open", hutClean(pod.openingHours) ?? (pod.isBookable ? nil : "Ask the hut"))
                row("Booking", pod.isBookable ? "In Podz" : "Through the hut")
            }
        }
    }

    @ViewBuilder
    private var gettingThere: some View {
        if let coordinate = pod.coordinate {
            DetailSection("Getting there") {
                VStack(alignment: .leading, spacing: 12) {
                    Button { openDirections(to: coordinate) } label: {
                        MapSnapshotImage(coordinate: coordinate)
                            .frame(height: 170)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Directions to \(pod.name)")

                    if let address = hutClean(pod.address) {
                        Text(address)
                            .font(AppFont.regularLabel(14))
                            .foregroundColor(.homeBodyText)
                    }
                    caption("Directions") { openDirections(to: coordinate) }
                }
            }
        }
    }

    @ViewBuilder
    private var contact: some View {
        let links = pod.contactLinks
        if !links.isEmpty {
            DetailSection("Contact") {
                VStack(spacing: 0) {
                    ForEach(links, id: \.label) { link in
                        row(link.label, link.value, opens: link.url)
                    }
                }
            }
        }
    }

    /// Where the information comes from, so nothing is taken on trust.
    @ViewBuilder
    private var source: some View {
        if !pod.isBookable || photoCredit != nil {
            DetailSection("About this listing") {
                VStack(alignment: .leading, spacing: 6) {
                    if !pod.isBookable {
                        note(pod.source == "osm"
                             ? "Information © OpenStreetMap contributors. Not checked by Podz."
                             : "Listed hut. Not checked by Podz.")
                    }
                    if let photoCredit { note("Photo: \(photoCredit)") }
                }
            }
        }
    }

    // MARK: - Pieces

    private var bedsText: String? {
        guard let total = pod.bedsTotal else { return nil }
        var text = "\(total)"
        if pod.isBookable, let live = liveBedsAvailable { text += " · \(live) free now" }
        return text
    }

    /// A label and its value with a hairline above; a row with no value is
    /// left out. With `opens` it's a button and shows a quiet chevron.
    @ViewBuilder
    private func row(_ label: String, _ value: String?, opens url: URL? = nil) -> some View {
        if let value, !value.isEmpty {
            let content = HStack(spacing: 12) {
                Text(label)
                    .font(AppFont.regularLabel(16))
                    .foregroundColor(.homeText)
                Spacer(minLength: 12)
                Text(value)
                    .font(AppFont.regularLabel(16))
                    .foregroundColor(.homeSubtitle)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if url != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.homeSubtitle)
                }
            }
            .frame(height: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { Rectangle().fill(Color.homeText.opacity(0.08)).frame(height: 1) }

            if let url {
                Button { openURL(url) } label: { content }.buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(AppFont.regularLabel(13))
            .foregroundColor(.homeSubtitle)
    }

    /// The small underlined grey caption with a chevron the app uses instead
    /// of a pill for a quiet action.
    private func caption(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).underline()
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
            }
            .font(AppFont.regularLabel(13))
            .foregroundColor(.homeSubtitle)
        }
        .buttonStyle(.plain)
    }

    private func openDirections(to coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        item.name = pod.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

/// A 13 `homeSubtitle` heading over a section's content.
private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

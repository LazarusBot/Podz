import SwiftUI

/// "See all": the whole shelf, not just the few cards it shows, on the same page
/// as every page Profile opens (title, content, the back pill, the fade). Under
/// the title the count and a quiet row of ways to look at it: the best documented
/// first, the highest, the biggest, A to Z, and only what's open now. Each card
/// says what the order is about (its altitude when sorted by height, its beds when
/// sorted by size) and carries what a traveler weighs: price and whether it's
/// open.
struct HomeAllPodsSheet: View {
    let title: String
    let pods: [Pod]
    let photoURLs: [UUID: String]
    var initialSort: Sort = .best

    enum Sort: CaseIterable {
        case best, highest, beds, name

        var label: String {
            switch self {
            case .best: "Best"
            case .highest: "Highest first"
            case .beds: "Most beds"
            case .name: "A–Z"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var sort: Sort
    @State private var onlyOpen = false
    @State private var selectedPod: Pod?
    @Namespace private var zoomNamespace

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(title: String, pods: [Pod], photoURLs: [UUID: String], initialSort: Sort = .best) {
        self.title = title
        self.pods = pods
        self.photoURLs = photoURLs
        self.initialSort = initialSort
        _sort = State(initialValue: initialSort)
    }

    // MARK: - What's shown

    private var photoIDs: Set<UUID> {
        Set(photoURLs.filter { !$0.value.isEmpty }.keys)
    }

    private var shown: [Pod] {
        var list = pods
        if onlyOpen { list = list.filter { OpeningStatus.evaluate($0.openingHours)?.isOpen == true } }
        switch sort {
        case .best: return PodQuality.ranked(list, photoIDs: photoIDs)
        case .highest: return list.sorted { ($0.altitudeM ?? -1) > ($1.altitudeM ?? -1) }
        case .beds: return list.sorted { ($0.bedsTotal ?? -1) > ($1.bedsTotal ?? -1) }
        case .name: return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Whether any hut says whether it's open: otherwise the chip would do nothing.
    private var offersOpenFilter: Bool {
        pods.contains { OpeningStatus.evaluate($0.openingHours) != nil }
    }

    // MARK: - Body

    var body: some View {
        // A tall fade, solid over its lower half: the photos can't be seen through
        // or around the back pill, and they melt away softly above it.
        SectionPage(title: title, onBack: { dismiss() }, fade: .photos, respectsSafeArea: true) {
            VStack(alignment: .leading, spacing: 0) {
                T("\(shown.count) \(shown.count == 1 ? "hut" : "huts")")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                chips
                    .padding(.bottom, 24)

                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(shown) { pod in
                        HomePodCard(
                            pod: pod,
                            photoURL: photoURLs[pod.id],
                            zoomNamespace: zoomNamespace,
                            subtitleOverride: subtitle(for: pod),
                            detailLine: detail(for: pod),
                            onTap: { selectedPod = pod }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .animation(.smooth(duration: 0.3), value: shown.map(\.id))
            }
        }
        .fullScreenCover(item: $selectedPod) { pod in
            MinimalPodDetailView(pod: pod, onBack: { selectedPod = nil })
                .navigationTransition(.zoom(sourceID: pod.id, in: zoomNamespace))
        }
    }

    // MARK: - The ways to look

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Sort.allCases, id: \.self) { option in
                    chip(option.label, isOn: sort == option) { sort = option }
                }
                if offersOpenFilter {
                    chip("Open now", isOn: onlyOpen) { onlyOpen.toggle() }
                }
            }
            .padding(.horizontal, 24)
        }
        .sensoryFeedback(.selection, trigger: sort)
    }

    /// A flat pill; the chosen one is inverted, like the pill that is the one to press.
    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { action() }
        } label: {
            T(title)
                .font(AppFont.regularLabel(14))
                .foregroundColor(isOn ? .homeBackground : .homeText)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(Capsule().fill(isOn ? Color.homeText : Color.homePill))
        }
        .buttonStyle(TapScaleButtonStyle())
    }

    // MARK: - What a card says

    /// The first line says what the order is about; otherwise the usual one.
    private func subtitle(for pod: Pod) -> String? {
        let place = pod.region ?? pod.country
        switch sort {
        case .highest:
            return [pod.altitudeM.map { "\($0.formatted(.number.grouping(.automatic))) m" }, place].compactMap { $0 }.joined(separator: " · ")
        case .beds:
            return [pod.bedsTotal.map { "\($0) \($0 == 1 ? "bed" : "beds")" }, place].compactMap { $0 }.joined(separator: " · ")
        case .best, .name:
            return nil
        }
    }

    /// What a traveler weighs: the price and whether it's open.
    private func detail(for pod: Pod) -> String? {
        var parts: [String] = []
        if let price = pod.priceText { parts.append(price) }
        if let status = OpeningStatus.evaluate(pod.openingHours) { parts.append(status.label) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

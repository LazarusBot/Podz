import SwiftUI

/// Inside a Likes folder: the pod detail's layout, with the folder's pods as
/// the pages. Swipe the photo to go through the pods; the title is the
/// folder's name and its count, the teaser names the pod on screen.
///
/// **Stack:** photo, title, teaser, back / (share) / Open.
/// **Extended:** tap the area under the photo and the photo shrinks to make
/// room for the list of every pod in the folder; tap the title to go back.
/// Paging through the photos is the only swipe on this screen.
struct MinimalFolderView: View {
    let name: String
    let pods: [Pod]
    let photoURLs: [UUID: String]
    var onBack: () -> Void
    var onOpenPod: (Pod) -> Void
    /// Nil for a folder that isn't yours — there's nothing to share.
    var onShare: (() -> Void)? = nil

    @State private var pageIndex: Int? = 0
    @State private var isExtended = false

    private var currentPod: Pod? {
        guard !pods.isEmpty else { return nil }
        return pods[min(max(pageIndex ?? 0, 0), pods.count - 1)]
    }

    var body: some View {
        GeometryReader { proxy in
            let screenHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let photoHeight = DetailLayout.photoHeight(screenHeight: screenHeight, isExtended: isExtended)

            VStack(spacing: 0) {
                DetailPhotoPager(
                    slots: pods.map { photoURLs[$0.id] },
                    pageIndex: $pageIndex,
                    width: proxy.size.width,
                    height: photoHeight
                )

                textArea

                actionRow
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 40)
            }
            .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.top)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.homeBackground.ignoresSafeArea())
        // This screen replaces the tab's content, so the floating tab bar
        // would sit on top of the buttons.
        .onAppear { TabBarVisibilityState.shared.isHidden = true }
        .onDisappear { TabBarVisibilityState.shared.isHidden = false }
    }

    // MARK: - Text

    private var title: some View {
        detailTitle(name, detail: "\(pods.count) \(pods.count == 1 ? "pod" : "pods")")
            .foregroundColor(.homeText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 50)
    }

    @ViewBuilder
    private var textArea: some View {
        if isExtended {
            VStack(spacing: 0) {
                title
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleExtended() }
                podList
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Everything between the photo and the buttons is one tap
            // target, like the pod detail.
            VStack(spacing: 0) {
                title
                teaser
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { toggleExtended() }
        }
    }

    /// The pod on screen: its name, then where it is.
    private var teaser: some View {
        Text(teaserText)
            .font(AppFont.regularLabel(16))
            .lineSpacing(5)
            .foregroundColor(.homeBodyText)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: 329)
            .padding(.top, 23)
            .padding(.horizontal, 32)
    }

    private var teaserText: String {
        guard let currentPod else { return "" }
        return Self.caption(for: currentPod)
    }

    private var podList: some View {
        ScrollView {
            VStack(spacing: 22) {
                ForEach(pods) { pod in
                    Button { onOpenPod(pod) } label: {
                        VStack(spacing: 3) {
                            Text(pod.name)
                                .font(AppFont.semiBoldLabel(16))
                                .foregroundColor(.homeText)
                            Text([pod.region, pod.country].compactMap { $0 }.joined(separator: ", "))
                                .font(AppFont.regularLabel(14))
                                .foregroundColor(.homeSubtitle)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .frame(maxHeight: .infinity)
    }

    private static func caption(for pod: Pod) -> String {
        let place = [pod.region, pod.country].compactMap { $0 }.joined(separator: ", ")
        return place.isEmpty ? pod.name : "\(pod.name), \(place)"
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 13) {
            DetailBackButton(action: onBack)

            if let onShare {
                DetailRoundButton(accessibilityLabel: "Share folder", action: onShare) {
                    Image(systemName: "link")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.homeText.opacity(0.45))
                }
            }

            DetailTextButton(title: "Open") {
                if let currentPod { onOpenPod(currentPod) }
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 24)
    }

    private func toggleExtended() {
        withAnimation(.smooth(duration: 0.45)) { isExtended.toggle() }
    }
}

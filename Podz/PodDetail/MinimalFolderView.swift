import SwiftUI

/// Inside a Likes folder (Paper "LikesFolderView" frames): a two-column
/// grid of the folder's pods. Tap a tile to select it (full strength, with
/// a check; the rest dim), then "Open" goes to the selected pod. The grid
/// scrolls under a fade into the ground and the back / share / Open pills.
struct MinimalFolderView: View {
    let pods: [Pod]
    let photoURLs: [UUID: String]
    var onBack: () -> Void
    var onOpenPod: (Pod) -> Void
    /// Nil for a folder that isn't yours — there's nothing to share.
    var onShare: (() -> Void)? = nil

    @State private var selectedID: UUID?

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    /// The picked pod, or the first one until something is picked (or if the
    /// picked pod left the folder).
    private var selectedPod: Pod? {
        pods.first { $0.id == selectedID } ?? pods.first
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(pods) { pod in
                        FolderPodTile(
                            pod: pod,
                            photoURL: photoURLs[pod.id],
                            isSelected: pod.id == selectedPod?.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: AppMotion.snappy)) { selectedID = pod.id }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                // Room to scroll the last row above the buttons.
                .padding(.bottom, 190)
            }

            // Fade into the ground behind the buttons.
            LinearGradient(
                stops: [.init(color: .clear, location: 0.5), .init(color: .homeBackground, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            actionRow
                .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        // This screen replaces the tab's content, so the floating tab bar
        // would sit on top of the buttons.
        .onAppear { TabBarVisibilityState.shared.isHidden = true }
        .onDisappear { TabBarVisibilityState.shared.isHidden = false }
    }

    private var actionRow: some View {
        HStack(spacing: 13) {
            DetailBackButton(action: onBack)

            if let onShare {
                DetailRoundButton(accessibilityLabel: "Share folder", action: onShare) {
                    LinkGlyphShape()
                        .stroke(Color.homeText.opacity(0.35), style: StrokeStyle(lineWidth: 0.96, lineCap: .round))
                        .frame(width: 18, height: 18)
                }
            }

            DetailTextButton(title: "Open") {
                if let selectedPod { onOpenPod(selectedPod) }
            }
        }
        .padding(.horizontal, 24)
    }
}

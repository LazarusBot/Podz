import SwiftUI

/// Inside a Likes folder (Paper "LikesFolderView" frames): a two-column
/// grid of the folder's pods. Tap a tile to select it (full strength, with
/// a check; the rest dim), then "Open" goes to the selected pod (in an empty folder of yours the pill asks "Add huts?" and goes to Home). The grid
/// scrolls under a fade into the ground and the back / share / Open pills.
struct MinimalFolderView: View {
    /// The folder's own name, as the page's title.
    let title: String
    /// Under the title: who shared it, for one that isn't yours. The count of
    /// pods when nil.
    var subtitle: String? = nil
    /// Who the folder is shared with: shown under the title, to manage.
    var sharedWith: [FolderPerson] = []
    let pods: [Pod]
    let photoURLs: [UUID: String]
    var onBack: () -> Void
    var onOpenPod: (Pod) -> Void
    /// Nil for a folder that isn't yours — there's nothing to share.
    var onShare: (() -> Void)? = nil
    /// Nil for a folder that isn't yours: nothing to take out of it.
    var onRemovePod: ((Pod) -> Void)? = nil
    /// Nil for a folder that isn't yours. While the folder is empty the last
    /// pill asks "Add huts?" and this takes you to Home to find some.
    var onAddHuts: (() -> Void)? = nil

    @State private var selectedID: UUID?
    /// Press and hold a tile: they wiggle and each gets a minus (yours only).
    @State private var isEditing = false

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    /// The picked pod, or the first one until something is picked (or if the
    /// picked pod left the folder).
    private var selectedPod: Pod? {
        pods.first { $0.id == selectedID } ?? pods.first
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                header

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(pods) { pod in
                        FolderPodTile(
                            pod: pod,
                            photoURL: photoURLs[pod.id],
                            isSelected: pod.id == selectedPod?.id,
                            isEditing: isEditing,
                            onTap: {
                                withAnimation(.easeInOut(duration: AppMotion.snappy)) { selectedID = pod.id }
                            },
                            onRemove: {
                                withAnimation(.smooth(duration: 0.35)) { onRemovePod?(pod) }
                            },
                            onLongPress: {
                                guard onRemovePod != nil else { return }
                                withAnimation(.smooth(duration: 0.3)) { isEditing = true }
                            }
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                // Room to scroll the last row above the buttons.
                .padding(.bottom, 190)
            }

            // Fade into the ground behind the buttons.
            BottomFade()

            actionRow
                .controlStackPadding()
        }
        .background(Color.homeBackground.ignoresSafeArea())
        // This screen replaces the tab's content, so the floating tab bar
        // would sit on top of the buttons.
        .onAppear { TabBarVisibilityState.shared.isHidden = true }
        .onDisappear { TabBarVisibilityState.shared.isHidden = false }
    }

    /// The folder's name, like the Likes and Home titles, and a quiet line under it.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.semiBoldLabel(30))
                .tracking(-0.6)
                .foregroundColor(.homeText)
                .lineLimit(2)
            T(subtitle ?? "\(pods.count) \(pods.count == 1 ? "hut" : "huts")")
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)

            if !sharedWith.isEmpty {
                sharedRow
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 25)
    }

    /// "Shared with Léa and 2 others ›", with their avatars: tap to manage.
    private var sharedRow: some View {
        Button { onShare?() } label: {
            HStack(spacing: 10) {
                SharedAvatars(people: sharedWith, size: 32, maxShown: 4)
                HStack(spacing: 5) {
                    T(sharedText)
                        .underline(color: Color.homeSubtitle.opacity(0.5))
                    if onShare != nil {
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                    }
                }
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onShare == nil)
    }

    private var sharedText: String {
        let names = sharedWith.map(\.name)
        switch names.count {
        case 0: return ""
        case 1: return "Shared with \(names[0])"
        case 2: return "Shared with \(names[0]) and \(names[1])"
        default: return "Shared with \(names[0]) and \(names.count - 1) others"
        }
    }

    private var asksToAddHuts: Bool { pods.isEmpty && onAddHuts != nil }

    private var pillTitle: String {
        isEditing ? "Done" : asksToAddHuts ? "Add huts?" : "Open"
    }

    private var actionRow: some View {
        HStack(spacing: 13) {
            DetailBackButton(action: onBack)

            if let onShare {
                DetailRoundButton(accessibilityLabel: "Share folder", action: onShare) {
                    // The app's own "link" symbol, as the old folder top bar had.
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.homeText.opacity(0.35))
                }
            }

            // While editing, the pill is Done (highlighted); in an empty folder
            // of yours it asks "Add huts?" (highlighted: it's the one move);
            // otherwise Open.
            DetailTextButton(title: pillTitle, isHighlighted: isEditing || asksToAddHuts) {
                if isEditing {
                    withAnimation(.smooth(duration: 0.3)) { isEditing = false }
                } else if asksToAddHuts {
                    onAddHuts?()
                } else if let selectedPod {
                    onOpenPod(selectedPod)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

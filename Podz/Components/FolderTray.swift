import SwiftUI

/// A Likes folder, drawn as a flat tray: a faint back wall, the pod photos
/// standing in it, and a low front lip in the pill color with the pod count.
/// Nothing is glass or shadowed (`design.md`). Everything is measured from
/// `side`, the square it's laid out in.
struct FolderTray: View {
    /// At most the first three are drawn.
    let previewPods: [Pod]
    let photoURLs: [UUID: String]
    let totalCount: Int
    let sharedWithAvatarURLs: [String]
    /// Drawn between the photos and the front lip, so a photo dropped in
    /// disappears behind the lip. Takes `side`.
    let incomingDropContent: ((CGFloat) -> AnyView)?
    let showDeleteBadge: Bool
    let scale: CGFloat
    let onDelete: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let backWallHeight = side * 0.74
            let lipHeight = side * 0.44
            let corner = side * 0.14

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.homePill.opacity(0.55))
                    .frame(height: backWallHeight)

                // Standing in the tray, tops clearing the back wall.
                ForEach(Array(previewPods.prefix(3).enumerated()), id: \.element.id) { index, pod in
                    FolderFanPhoto(url: photoURLs[pod.id], side: side)
                        .rotationEffect(.degrees(Self.rotation(for: index)))
                        .offset(x: Self.xOffset(for: index, side: side), y: -side * 0.15)
                        // A newly added photo pops in rather than swapping
                        // silently, like the count rolling beside it.
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }

                if let incomingDropContent {
                    incomingDropContent(side)
                }

                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color.homePill)

                    PodCountBadge(count: totalCount)
                        .padding(side * 0.06)
                }
                .frame(height: lipHeight)
                .overlay(alignment: .bottomLeading) { sharedAvatars(side: side) }
            }
            .frame(width: side, height: side, alignment: .bottom)
            .overlay(alignment: .topTrailing) {
                if showDeleteBadge {
                    Button(action: onDelete) {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.red))
                            .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 1.5))
                    }
                    .accessibilityLabel("Remove folder")
                    // On the back wall's top corner.
                    .offset(x: 4 * scale, y: (side - backWallHeight) - 6 * scale)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Friends this folder is shared with (or the owner, on a folder shared
    /// with you), overlapping on the lip's bottom-leading corner.
    @ViewBuilder
    private func sharedAvatars(side: CGFloat) -> some View {
        if !sharedWithAvatarURLs.isEmpty {
            HStack(spacing: -side * 0.05) {
                // Identified by the URL itself, not position, so a recycled
                // image view never keeps a previous row's avatar.
                ForEach(sharedWithAvatarURLs.prefix(3), id: \.self) { url in
                    AvatarView(imageName: url, size: side * 0.18)
                        // Opaque backing: overlapping circles would show
                        // through each other during the fade-in.
                        .background(Circle().fill(Color.homeBackground))
                        .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 1.5))
                }
            }
            .padding(side * 0.06)
        }
    }

    private static func rotation(for index: Int) -> Double { [-5, 4, -1][index % 3] }

    private static func xOffset(for index: Int, side: CGFloat) -> CGFloat {
        [-side * 0.14, side * 0.13, side * 0.0][index % 3]
    }
}

/// How many pods are in a folder: a ground-colored dot on the lip with the
/// number in `homeText`. The number rolls when it changes (inside a
/// `withAnimation`, see `LikesStore.like()`).
struct PodCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.homeText)
            .contentTransition(.numericText(value: Double(count)))
            .frame(minWidth: 22, minHeight: 22)
            .background(Circle().fill(Color.homeBackground))
    }
}

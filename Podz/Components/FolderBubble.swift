import SwiftUI

/// One folder as a bubble (Paper "LikesFolderSheet"): a flat shape in the
/// pill color with the folder's name in the middle, and up to two of its
/// pods' photos tucked inside its edge at half strength. Its size and the
/// flat cuts where neighbors press in come from its `FoamCell`
/// (`FolderBubbleCanvas` packs them).
struct FolderBubble: View {
    let cell: FoamCell
    let name: String
    /// A quiet line under the name, e.g. "by Léa" on a folder shared with you.
    var subtitle: String? = nil
    let pods: [Pod]
    let photoURLs: [UUID: String]
    /// Alternate bubbles mirror their photos, so the photos don't line up.
    var mirrored = false
    /// Avatars of friends the folder is shared with, under the name.
    var sharedWithAvatarURLs: [String] = []
    /// When set, the middle shows a name field instead (a new folder).
    var editableName: Binding<String>? = nil
    var onCommitName: (() -> Void)? = nil
    /// Drawn above the bubble; takes its diameter. Used for the photo that
    /// drops in while you save a like.
    var incomingDropContent: ((CGFloat) -> AnyView)? = nil
    var showDeleteBadge = false
    var isWiggling = false
    var onDelete: () -> Void = {}
    var onLongPress: () -> Void = {}
    var onTap: () -> Void = {}

    /// The Paper frame's full-size bubble: 300 across.
    static let referenceRadius: CGFloat = 150
    static let photoSize = CGSize(width: 119, height: 141)

    /// Where the photos sit at full size, from the center, in points.
    private static let photoOffsets: [CGSize] = [CGSize(width: 79, height: -89), CGSize(width: -71, height: 97)]

    private var scale: CGFloat { cell.radius / Self.referenceRadius }

    @FocusState private var nameFocused: Bool
    @State private var isPressed = false
    @State private var wiggleAngle: Double = 0

    var body: some View {
        ZStack {
            FoamCellView(cell: cell)

            // Photos stay inside the bubble: cut off at its edges.
            ZStack {
                ForEach(Array(pods.prefix(2).enumerated()), id: \.element.id) { index, pod in
                    let offset = Self.photoOffsets[index]
                    BubblePhoto(url: photoURLs[pod.id])
                        .scaleEffect(scale)
                        .opacity(0.55)
                        .offset(x: (mirrored ? -offset.width : offset.width) * scale, y: offset.height * scale)
                        // A newly added pod pops in rather than swapping
                        // silently.
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .mask(FoamCellView(cell: cell, color: .black))

            label

            if let incomingDropContent {
                incomingDropContent(cell.radius * 2)
            }
        }
        .frame(width: cell.radius * 2, height: cell.radius * 2)
        .overlay { deleteBadge }
        .contentShape(Circle())
        .scaleEffect(isPressed ? 0.98 : 1)
        .rotationEffect(.degrees(isWiggling ? wiggleAngle : 0))
        .onTapGesture {
            guard editableName == nil, !showDeleteBadge else { return }
            onTap()
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    guard editableName == nil else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onLongPress()
                }
        )
        .onChange(of: isWiggling) { _, wiggling in
            if wiggling {
                withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                    wiggleAngle = Double.random(in: 0.8...1.2)
                }
            } else {
                withAnimation(.linear(duration: 0)) { wiggleAngle = 0 }
            }
        }
        .accessibilityElement(children: editableName == nil ? .ignore : .contain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(editableName == nil ? .isButton : [])
    }

    // MARK: - Pieces

    @ViewBuilder
    private var label: some View {
        if let editableName {
            TextField("Folder name", text: editableName)
                .font(AppFont.semiBoldLabel(15))
                .foregroundColor(.homeText)
                .multilineTextAlignment(.center)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { onCommitName?() }
                .onAppear { nameFocused = true }
                .frame(width: min(170, cell.radius * 1.5))
        } else {
            VStack(spacing: 6) {
                Text(name)
                    .font(AppFont.semiBoldLabel(15))
                    .foregroundColor(.homeText)
                    .lineLimit(1)
                    .frame(maxWidth: cell.radius * 1.5)

                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.regularLabel(12))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(1)
                }

                if !sharedWithAvatarURLs.isEmpty {
                    // Identified by the URL itself, not position, so a
                    // recycled image view never keeps a previous avatar.
                    HStack(spacing: -6) {
                        ForEach(sharedWithAvatarURLs.prefix(3), id: \.self) { url in
                            AvatarView(imageName: url, size: 24)
                                // Opaque backing: overlapping circles would
                                // show through each other while fading in.
                                .background(Circle().fill(Color.homePill))
                                .overlay(Circle().strokeBorder(Color.homePill, lineWidth: 1.5))
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var deleteBadge: some View {
        if showDeleteBadge {
            Button(action: onDelete) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.red))
                    .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 1.5))
            }
            .accessibilityLabel("Remove folder")
            // On the rim, at about two o'clock.
            .offset(x: cell.radius * 0.707, y: -cell.radius * 0.707)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// A pod photo as it sits against a bubble (119 x 141, radius 30).
struct BubblePhoto: View {
    let url: String?

    var body: some View {
        PodPhoto(url: url)
            .frame(width: FolderBubble.photoSize.width, height: FolderBubble.photoSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

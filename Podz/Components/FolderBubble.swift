import SwiftUI

/// One folder in the save-to-folder sheet (Paper "LikesFolderSheet"): a big
/// flat circle in the pill color with the folder's name in the middle, and
/// up to two of its pods' photos tucked against its edge at half strength.
/// A tap saves into it.
struct FolderBubble: View {
    let name: String
    let pods: [Pod]
    let photoURLs: [UUID: String]
    /// Bubbles on the right of the zig-zag mirror their photos, so the
    /// photos stay toward the middle of the screen.
    var mirrored = false
    /// When set, the middle shows a name field instead (a new folder).
    var editableName: Binding<String>? = nil
    var onCommitName: (() -> Void)? = nil
    /// Drawn above the bubble; takes its diameter. Used for the photo that
    /// drops in while you save a like.
    var incomingDropContent: ((CGFloat) -> AnyView)? = nil
    var onTap: () -> Void = {}

    static let diameter: CGFloat = 300
    static let photoSize = CGSize(width: 119, height: 141)

    /// Where the photos sit, from the circle's center, in points.
    private static let photoOffsets: [CGSize] = [CGSize(width: 79, height: -89), CGSize(width: -71, height: 97)]

    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Circle().fill(Color.homePill)

            ForEach(Array(pods.prefix(2).enumerated()), id: \.element.id) { index, pod in
                let offset = Self.photoOffsets[index]
                BubblePhoto(url: photoURLs[pod.id])
                    .opacity(0.55)
                    .offset(x: mirrored ? -offset.width : offset.width, y: offset.height)
                    // A newly added pod pops in rather than swapping
                    // silently.
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }

            label

            if let incomingDropContent {
                incomingDropContent(Self.diameter)
            }
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .contentShape(Circle())
        .onTapGesture {
            if editableName == nil { onTap() }
        }
        .accessibilityElement(children: editableName == nil ? .ignore : .contain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(editableName == nil ? .isButton : [])
    }

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
                .frame(width: 170)
        } else {
            Text(name)
                .font(AppFont.semiBoldLabel(15))
                .foregroundColor(.homeText)
                .lineLimit(1)
                .frame(maxWidth: 200)
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

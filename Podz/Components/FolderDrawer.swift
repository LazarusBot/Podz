import SwiftUI

/// A Likes folder, drawn as a drawer front (the drawer-cabinet reference):
/// a flat colored bar with a paper label tag on the left carrying the
/// folder's name and pod count, and a handle. No photos. Tap opens it.
/// Everything is measured from the width it's given.
struct FolderDrawer: View {
    let name: String
    /// A quiet line under the name, e.g. "by Léa" on a folder shared with you.
    var subtitle: String? = nil
    let count: Int
    let color: FolderColor
    /// When set, the label shows a name field instead (a new folder).
    var editableName: Binding<String>? = nil
    var onCommitName: (() -> Void)? = nil
    var sharedWithAvatarURLs: [String] = []
    /// Drawn above the drawer; takes its width. Used for the photo that
    /// drops in while you save a like.
    var incomingDropContent: ((CGFloat) -> AnyView)? = nil
    var showDeleteBadge = false
    var onDelete: () -> Void = {}

    @FocusState private var nameFocused: Bool

    /// Width : height of one drawer.
    static let aspect: CGFloat = 345 / 76

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = w / Self.aspect

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: h * 0.2, style: .continuous)
                    .fill(color.color)

                label(width: w, height: h)
                    .padding(.leading, h * 0.2)

                // Handle: a slot in a darker shade of the drawer.
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: w * 0.16, height: h * 0.16)
                    .position(x: w * 0.62, y: h / 2)

                if !sharedWithAvatarURLs.isEmpty {
                    avatars(height: h)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, h * 0.2)
                }

                if let incomingDropContent {
                    incomingDropContent(w)
                        .frame(width: w, height: h, alignment: .bottom)
                }
            }
            .frame(width: w, height: h)
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
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
    }

    /// The same size on every drawer, like the labels on the reference.
    private func label(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                if let editableName {
                    TextField("Folder name", text: editableName)
                        .font(AppFont.semiBoldLabel(15))
                        .foregroundColor(.folderTagInk)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { onCommitName?() }
                        .onAppear { nameFocused = true }
                } else {
                    Text(name)
                        .font(AppFont.semiBoldLabel(15))
                        .foregroundColor(.folderTagInk)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.regularLabel(11))
                            .foregroundColor(.folderTagSubtitle)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            // Rolls when it changes (inside a `withAnimation`, see
            // `LikesStore.like()`).
            Text("\(count)")
                .font(AppFont.regularLabel(12))
                .foregroundColor(.folderTagSubtitle)
                .contentTransition(.numericText(value: Double(count)))
        }
        .padding(.horizontal, 12)
        .frame(width: width * 0.4, height: height * 0.62)
        .background(Color.folderTagPaper, in: RoundedRectangle(cornerRadius: height * 0.1, style: .continuous))
    }

    private func avatars(height: CGFloat) -> some View {
        // Identified by the URL itself, not position, so a recycled image
        // view never keeps a previous row's avatar.
        HStack(spacing: -6) {
            ForEach(sharedWithAvatarURLs.prefix(3), id: \.self) { url in
                AvatarView(imageName: url, size: height * 0.42)
                    // Opaque backing: overlapping circles would show
                    // through each other during the fade-in.
                    .background(Circle().fill(color.color))
                    .overlay(Circle().strokeBorder(color.color, lineWidth: 1.5))
            }
        }
    }
}

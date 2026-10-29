import SwiftUI

/// A Likes folder, drawn as a paper tray: a faint back wall, a stack of
/// sheets whose edges show in front, the top sheet carrying the newest pod's
/// photo and the folder's name, and a low front lip in the pill color with
/// the shared-with avatars and the pod count. Flat: nothing is glass or
/// shadowed (`design.md`). Everything is measured from the width it's given.
struct PaperTray: View {
    let name: String
    /// A quiet line on the lip, e.g. "by Léa" on a folder shared with you.
    var subtitle: String? = nil
    let pods: [Pod]
    let photoURLs: [UUID: String]
    /// When set, the top sheet shows a name field instead (a new folder).
    var editableName: Binding<String>? = nil
    var onCommitName: (() -> Void)? = nil
    var sharedWithAvatarURLs: [String] = []
    /// Drawn above the sheets but below the lip, so a photo dropped in goes
    /// into the tray. Takes the tray's width.
    var incomingDropContent: ((CGFloat) -> AnyView)? = nil
    var showDeleteBadge = false
    var onDelete: () -> Void = {}

    @FocusState private var nameFocused: Bool

    /// Width : height of the whole tray.
    static let aspect: CGFloat = 1 / 0.66

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = w / Self.aspect
            let sheetWidth = w * 0.86
            let sheetX = (w - sheetWidth) / 2
            let topY = w * 0.10
            let topHeight = w * 0.42
            let strip = w * 0.022
            let lipHeight = w * 0.07
            let corner = w * 0.05
            // An empty folder still shows one blank sheet.
            let sheetCount = max(1, min(pods.count, 4))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .fill(Color.homePill.opacity(0.55))
                    .frame(width: w * 0.92, height: h * 0.7)
                    .offset(x: w * 0.04)

                // Sheets underneath, bottom first: only their edges show.
                ForEach(Array((1..<sheetCount).reversed()), id: \.self) { index in
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color.homeBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .strokeBorder(Color.homeText.opacity(0.14), lineWidth: 0.5)
                        )
                        .frame(width: sheetWidth, height: topHeight)
                        .offset(x: sheetX, y: topY + strip * CGFloat(index))
                }

                topSheet(width: sheetWidth, height: topHeight, corner: corner)
                    .offset(x: sheetX, y: topY)
                    // A newly added pod becomes the top sheet.
                    .id(pods.first?.id)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))

                if let incomingDropContent {
                    incomingDropContent(w)
                        .frame(width: w, height: h, alignment: .bottom)
                }

                lip(width: w, height: lipHeight, corner: corner)
                    .offset(y: h - lipHeight)
            }
            .frame(width: w, height: h, alignment: .topLeading)
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
                    .padding(.trailing, sheetX - 6)
                    .padding(.top, topY - 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
    }

    // MARK: - Pieces

    private func topSheet(width: CGFloat, height: CGFloat, corner: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let pod = pods.first {
                PodPhoto(url: photoURLs[pod.id])
                    .frame(width: width, height: height)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    .frame(height: height * 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            } else {
                Color.homeBackground
            }

            if let editableName {
                TextField("Folder name", text: editableName)
                    .font(AppFont.semiBoldLabel(15))
                    .foregroundColor(.homeText)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { onCommitName?() }
                    .onAppear { nameFocused = true }
                    .padding(.leading, 18)
                    .padding(.trailing, 12)
                    .padding(.bottom, 14)
            } else {
                Text(name)
                    .font(AppFont.semiBoldLabel(15))
                    .foregroundColor(pods.isEmpty ? .homeText : .white)
                    .lineLimit(1)
                    .padding(.leading, 18)
                    .padding(.trailing, 12)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.homeText.opacity(pods.isEmpty ? 0.14 : 0), lineWidth: 0.5)
        )
    }

    private func lip(width: CGFloat, height: CGFloat, corner: CGFloat) -> some View {
        HStack(spacing: 8) {
            // Identified by the URL itself, not position, so a recycled
            // image view never keeps a previous row's avatar.
            HStack(spacing: -5) {
                ForEach(sharedWithAvatarURLs.prefix(3), id: \.self) { url in
                    AvatarView(imageName: url, size: height * 0.72)
                        // Opaque backing: overlapping circles would show
                        // through each other during the fade-in.
                        .background(Circle().fill(Color.homeBackground))
                        .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 1))
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(AppFont.regularLabel(11))
                    .foregroundColor(.homeSubtitle)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            PodCountBadge(count: pods.count)
        }
        .padding(.horizontal, width * 0.07)
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Color.homePill)
        )
    }
}

/// How many pods are in a folder: a ground-colored dot on the lip with the
/// number in `homeText`. The number rolls when it changes (inside a
/// `withAnimation`, see `LikesStore.like()`).
struct PodCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.homeText)
            .contentTransition(.numericText(value: Double(count)))
            .frame(minWidth: 18, minHeight: 18)
            .background(Circle().fill(Color.homeBackground))
    }
}

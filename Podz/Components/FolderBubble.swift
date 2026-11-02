import SwiftUI
import CoreLocation

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
    /// The friends the folder is shared with: their avatars, under the name.
    var sharedWith: [FolderPerson] = []
    /// When set, the middle shows a name field instead (a new folder).
    var editableName: Binding<String>? = nil
    var onCommitName: (() -> Void)? = nil
    /// A swell while a pod melts in; the other bubbles give way (a small shift
    /// away from it, and a hair smaller), the farther ones a beat later, so the
    /// bump travels through the foam.
    var swell: CGFloat = 1
    var reactionOffset: CGSize = .zero
    var reactionDelay: Double = 0
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
    static let photoOffsets: [CGSize] = [CGSize(width: 79, height: -89), CGSize(width: -71, height: 97)]

    private var scale: CGFloat { cell.radius / Self.referenceRadius }

    /// The pods whose photos are drawn: all of them, up to a sensible number
    /// (past that they'd only be a blur).
    private var shownPods: [Pod] { Array(pods.prefix(Self.maxPhotos)) }
    static let maxPhotos = 24

    /// Where one photo sits at the full-size bubble: one or two keep their
    /// place, more spread on a spiral that fills the bubble, each smaller the
    /// more there are and tilted a little by a stable amount.
    static func placement(index: Int, count: Int, seed: String) -> (offset: CGSize, scale: CGFloat, rotation: Double) {
        if count <= 2 { return (photoOffsets[min(index, 1)], 1.08, 0) }
        let radius = referenceRadius * 0.85 * sqrt((CGFloat(index) + 0.5) / CGFloat(count))
        let angle = CGFloat(index) * 2.39996   // the golden angle: even spread
        let scale = max(0.52, min(1.12, 1.95 / sqrt(CGFloat(count))))
        let tilt = (Double(FoamLayout.jitter(seed, salt: 11)) - 0.5) * 12
        return (CGSize(width: radius * cos(angle), height: radius * sin(angle)), scale, tilt)
    }

    @FocusState private var nameFocused: Bool
    @State private var isPressed = false
    @State private var wiggleAngle: Double = 0

    var body: some View {
        ZStack {
            FoamCellView(cell: cell)

            // Every pod's photo is inside the bubble, overlapping where there are
            // many (smaller the more there are), cut off at its edges.
            ZStack {
                ForEach(Array(shownPods.enumerated()), id: \.element.id) { index, pod in
                    let place = Self.placement(index: index, count: shownPods.count, seed: pod.id.uuidString)
                    BubblePhoto(url: photoURLs[pod.id], coordinate: pod.coordinate)
                        .scaleEffect(scale * place.scale)
                        .rotationEffect(.degrees(place.rotation))
                        .opacity(shownPods.count > 2 ? 0.7 : 0.55)
                        .offset(
                            x: (mirrored ? -place.offset.width : place.offset.width) * scale,
                            y: place.offset.height * scale
                        )
                        // A newly added pod pops in rather than swapping
                        // silently.
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.5), value: shownPods.map(\.id))
            .mask(FoamCellView(cell: cell, color: .black))

            label

            if let incomingDropContent {
                incomingDropContent(cell.radius * 2)
            }
        }
        .frame(width: cell.radius * 2, height: cell.radius * 2)
        .overlay { deleteBadge }
        .contentShape(Circle())
        .scaleEffect((isPressed ? 0.98 : 1) * swell)
        .offset(reactionOffset)
        .animation(.smooth(duration: 0.55).delay(reactionDelay), value: swell)
        .animation(.smooth(duration: 0.55).delay(reactionDelay), value: reactionOffset)
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
            TextField(tr("Folder name"), text: editableName)
                .font(AppFont.semiBoldLabel(15))
                .foregroundColor(.homeText)
                .multilineTextAlignment(.center)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { onCommitName?() }
                .onAppear { nameFocused = true }
                .frame(width: min(170, cell.radius * 1.5))
        } else {
            // The name sits on a solid label, so it reads over the photos, and the
            // avatars of whoever it's shared with go with it: bigger, each cut out
            // of the label by a ring of its own color.
            VStack(spacing: 7) {
                Text(name)
                    .font(AppFont.semiBoldLabel(15))
                    .foregroundColor(.homeText)
                    .lineLimit(1)

                if let subtitle {
                    T(subtitle)
                        .font(AppFont.regularLabel(12))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(1)
                }

                if !sharedWith.isEmpty {
                    SharedAvatars(people: sharedWith, size: 30, maxShown: 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: cell.radius * 1.5)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.homeBackground))
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
            .accessibilityLabel(tr("Remove folder"))
            // On the rim, at about two o'clock.
            .offset(x: cell.radius * 0.707, y: -cell.radius * 0.707)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// A friend a folder is shared with.
struct FolderPerson: Identifiable, Equatable {
    let id: UUID
    let name: String
    let avatarURL: String?
}

/// Overlapping round avatars, each with a ring in the ground's color, then "+2"
/// for the rest.
struct SharedAvatars: View {
    let people: [FolderPerson]
    var size: CGFloat = 30
    var maxShown = 3

    var body: some View {
        HStack(spacing: -size * 0.28) {
            ForEach(people.prefix(maxShown)) { person in
                AvatarView(imageName: person.avatarURL, size: size)
                    // Opaque backing: overlapping circles would show through each
                    // other while fading in.
                    .background(Circle().fill(Color.homePill))
                    .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 2.5))
            }
            if people.count > maxShown {
                Text("+\(people.count - maxShown)")
                    .font(AppFont.semiBoldLabel(size * 0.4))
                    .foregroundColor(.homeText)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.homePill))
                    .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 2.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(people.map(\.name).joined(separator: ", "))
    }
}

/// A pod photo as it sits against a bubble (119 x 141, radius 30).
struct BubblePhoto: View {
    let url: String?
    var coordinate: CLLocationCoordinate2D?

    var body: some View {
        PodPhoto(url: url, coordinate: coordinate)
            .frame(width: FolderBubble.photoSize.width, height: FolderBubble.photoSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

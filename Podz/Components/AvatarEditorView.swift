import SwiftUI
import UIKit

/// Adjusts your current profile photo (opened by a long press on it): pinch
/// to zoom, drag to move, turn it a quarter, then **Save**. The round window
/// is what the photo will show; what falls outside is dimmed. The result is
/// the square under the window, sent as the new photo.
struct AvatarEditorView: View {
    let imageURL: String?
    var onClose: () -> Void

    @State private var image: UIImage?
    @State private var failedToLoad = false
    @State private var zoom: CGFloat = 1
    @State private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var drag: CGSize = .zero
    @State private var quarterTurns = 0
    @State private var isSaving = false
    /// The window's size on screen, to scale the move when it's rendered bigger.
    @State private var windowDiameter: CGFloat = 330
    @State private var errorMessage: String?

    private static let maxZoom: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width - 48, 330)

            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Adjust photo")
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(-0.6)
                        .foregroundColor(.homeText)
                        .padding(.horizontal, 24)
                        .padding(.top, 25)

                    Text("Pinch to zoom, drag to move")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)

                    Spacer(minLength: 0)

                    editor(diameter: diameter)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 22) {
                        caption("Rotate") { withAnimation(.smooth(duration: 0.3)) { quarterTurns = (quarterTurns + 1) % 4 } }
                        caption("Reset") { reset() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)

                    Spacer(minLength: 0)
                    Color.clear.frame(height: 83 + 40 + 24)
                }

                HStack(spacing: 13) {
                    DetailBackButton(action: onClose)
                    DetailTextButton(title: isSaving ? "Saving…" : "Save", isHighlighted: image != nil && !isSaving, action: save)
                        .disabled(image == nil || isSaving)
                        .opacity(image == nil ? 0.45 : 1)
                }
                .padding(.horizontal, 24)
                // A cover respects the safe area: 40 here is the 74 from the edge.
                .padding(.bottom, 40)
            }
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .task { await load() }
        .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - The window

    private func editor(diameter: CGFloat) -> some View {
        ZStack {
            if let image {
                photo(image, diameter: diameter)
                    .onAppear { windowDiameter = diameter }
                    .frame(width: diameter, height: diameter)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            MagnifyGesture().onChanged { pinch = $0.magnification }.onEnded { value in
                                zoom = min(max(zoom * value.magnification, 1), Self.maxZoom)
                                pinch = 1
                                offset = clamped(offset, image: image, diameter: diameter, zoom: zoom)
                            },
                            DragGesture().onChanged { drag = $0.translation }.onEnded { value in
                                offset = clamped(
                                    CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height),
                                    image: image, diameter: diameter, zoom: zoom
                                )
                                drag = .zero
                            }
                        )
                    )
                    // What falls outside the round window is dimmed.
                    .overlay {
                        Rectangle()
                            .fill(Color.homeBackground.opacity(0.7))
                            .mask {
                                Rectangle().overlay(Circle().blendMode(.destinationOut))
                                    .compositingGroup()
                            }
                            .allowsHitTesting(false)
                    }
                    .overlay(Circle().strokeBorder(Color.homeText.opacity(0.25), lineWidth: 0.5).allowsHitTesting(false))
            } else if failedToLoad {
                Text("Couldn't open your photo.")
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.homeSubtitle)
                    .frame(width: diameter, height: diameter)
            } else {
                ProgressView().frame(width: diameter, height: diameter)
            }
        }
    }

    /// The photo at the window's size: the short side fills it at zoom 1.
    /// This same view is what gets rendered for the upload.
    private func photo(_ image: UIImage, diameter: CGFloat, liveGestures: Bool = true, moveScale: CGFloat = 1) -> some View {
        let turned = quarterTurns % 2 == 1
        let width = turned ? image.size.height : image.size.width
        let height = turned ? image.size.width : image.size.height
        let base = diameter / min(width, height)
        let scale = liveGestures ? min(max(zoom * pinch, 1), Self.maxZoom) : zoom
        let live = liveGestures
            ? CGSize(width: offset.width + drag.width, height: offset.height + drag.height)
            : offset
        let move = CGSize(width: live.width * moveScale, height: live.height * moveScale)
        return Image(uiImage: image)
            .resizable()
            .frame(width: image.size.width * base, height: image.size.height * base)
            .rotationEffect(.degrees(Double(quarterTurns) * 90))
            .scaleEffect(scale)
            .offset(move)
            .frame(width: diameter, height: diameter)
    }

    /// Keeps the photo covering the window, so no gap shows at the edges.
    private func clamped(_ proposed: CGSize, image: UIImage, diameter: CGFloat, zoom: CGFloat) -> CGSize {
        let turned = quarterTurns % 2 == 1
        let width = turned ? image.size.height : image.size.width
        let height = turned ? image.size.width : image.size.height
        let base = diameter / min(width, height)
        let limitX = max(0, (width * base * zoom - diameter) / 2)
        let limitY = max(0, (height * base * zoom - diameter) / 2)
        return CGSize(
            width: min(max(proposed.width, -limitX), limitX),
            height: min(max(proposed.height, -limitY), limitY)
        )
    }

    private func caption(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
                .underline(color: Color.homeSubtitle.opacity(0.5))
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reset() {
        withAnimation(.smooth(duration: 0.3)) {
            zoom = 1
            offset = .zero
            quarterTurns = 0
        }
    }

    // MARK: - Loading and saving

    private func load() async {
        guard let imageURL, let url = URL(string: imageURL) else {
            failedToLoad = true
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let loaded = UIImage(data: data) {
                image = loaded
            } else {
                failedToLoad = true
            }
        } catch {
            failedToLoad = true
        }
    }

    /// Renders the square under the window and sends it.
    private func save() {
        guard let image, !isSaving else { return }
        isSaving = true
        // 400 points drawn at 2x for a sharp photo; the move made on screen is
        // scaled up to match.
        let diameter: CGFloat = 400
        let renderer = ImageRenderer(
            content: photo(image, diameter: diameter, liveGestures: false, moveScale: diameter / windowDiameter)
        )
        renderer.scale = 2
        guard let rendered = renderer.uiImage, let jpeg = rendered.jpegData(compressionQuality: 0.85) else {
            isSaving = false
            errorMessage = "Couldn't prepare the photo."
            return
        }
        Task {
            do {
                try await AvatarUploader.upload(jpeg: jpeg)
                isSaving = false
                onClose()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

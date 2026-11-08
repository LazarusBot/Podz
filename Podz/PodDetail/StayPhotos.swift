import SwiftUI
import ImageIO

/// A kept photo, read from the phone at the size it's shown (thumbnails stay
/// small in memory; the viewer reads it larger).
struct StayPhotoImage: View {
    let url: URL
    var maxPixel: CGFloat = 400
    var fits = false
    @State private var image: UIImage?

    var body: some View {
        Color.homePill
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fits ? .fit : .fill)
                }
            }
            .clipped()
            .task(id: url) {
                let url = url, maxPixel = maxPixel
                image = await Task.detached(priority: .utility) { Self.read(url, maxPixel: maxPixel) }.value
            }
    }

    private nonisolated static func read(_ url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map(UIImage.init(cgImage:))
    }
}

/// "Your photos" on the extended pod page: the photos kept at stays in this
/// hut, as a quiet grid of rounded squares. Tap one to look at it.
struct YourPhotosSection: View {
    let podId: UUID
    @ObservedObject private var store = StayFeedbackStore.shared
    @State private var viewing: StayFeedbackStore.KeptPhoto?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        let photos = store.keptPhotos(forPod: podId)
        DetailSection("Your photos") {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(photos) { photo in
                    Button { viewing = photo } label: {
                        StayPhotoImage(url: photo.url, maxPixel: 360)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Your photo"))
                }
            }
        }
        .fullScreenCover(item: $viewing) { photo in
            StayPhotoViewer(podId: podId, start: photo, onClose: { viewing = nil })
        }
    }
}

/// One photo at a time, full width, with the control stack: back, and Delete
/// (Lenny asks first).
struct StayPhotoViewer: View {
    let podId: UUID
    let start: StayFeedbackStore.KeptPhoto
    var onClose: () -> Void

    @ObservedObject private var store = StayFeedbackStore.shared
    @State private var selection: String?
    @State private var asksToDelete = false

    private var photos: [StayFeedbackStore.KeptPhoto] { store.keptPhotos(forPod: podId) }
    private var current: StayFeedbackStore.KeptPhoto? {
        photos.first { $0.id == selection } ?? photos.first { $0.id == start.id } ?? photos.first
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.homeBackground.ignoresSafeArea()

            TabView(selection: Binding(get: { current?.id }, set: { selection = $0 })) {
                ForEach(photos) { photo in
                    StayPhotoImage(url: photo.url, maxPixel: 1600, fits: true)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        // Room for the count and the pills.
                        .padding(.bottom, 83 + DetailLayout.controlStackGap + 48)
                        .tag(Optional(photo.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)

            if photos.count > 1, let index = photos.firstIndex(where: { $0.id == current?.id }) {
                T("\(index + 1) of \(photos.count)")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .padding(.bottom, 83 + DetailLayout.controlStackGap + 16)
            }

            HStack(spacing: 13) {
                DetailBackButton(action: onClose)
                DetailTextButton(title: "Delete photo") { asksToDelete = true }
            }
            .padding(.horizontal, 24)
            // A cover respects the safe area: the gap alone puts the stack where
            // every control stack is.
            .padding(.bottom, DetailLayout.controlStackGap)
        }
        .lennyAsks(
            isPresented: $asksToDelete,
            question: "Delete this photo?",
            confirm: "Delete",
            keep: "Keep it",
            respectsSafeArea: true
        ) {
            guard let photo = current else { return }
            store.removePhoto(photo)
            if store.keptPhotos(forPod: podId).isEmpty { onClose() }
        }
    }
}

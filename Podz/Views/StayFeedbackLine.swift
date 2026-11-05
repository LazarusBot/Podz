import SwiftUI
import ImageIO

/// Under a finished stay in Reservations: how it went, as the traveler told
/// Lenny, and the photos they kept with it.
struct StayFeedbackLine: View {
    let reservationId: UUID
    @ObservedObject private var store = StayFeedbackStore.shared

    var body: some View {
        if let feedback = store.entries[reservationId], let mood = feedback.mood {
            VStack(alignment: .leading, spacing: 8) {
                T(mood == .good ? "A good stay" : "Not a great stay")
                    .font(AppFont.regularLabel(12))
                    .foregroundColor(.homeSubtitle)
                let urls = store.photoURLs(for: reservationId)
                if !urls.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(urls.prefix(4)), id: \.self) { url in
                            StayPhotoThumb(url: url)
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
    }
}

/// A small square of a kept photo, read at thumbnail size.
private struct StayPhotoThumb: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Color.homePill
            .frame(width: 36, height: 36)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .task(id: url) {
                image = await Task.detached(priority: .utility) { Self.thumbnail(at: url) }.value
            }
    }

    private nonisolated static func thumbnail(at url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 120
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map(UIImage.init(cgImage:))
    }
}

import SwiftUI
import CoreLocation

/// Shared photo loader: remote URL via AsyncImage, gray placeholder
/// otherwise. Same pattern as AvatarView.
struct PodPhoto: View {
    var url: String?
    /// Where the pod is: with no photo, the picture is the satellite view of
    /// this spot.
    var coordinate: CLLocationCoordinate2D?
    /// `.fill` everywhere by default (existing call sites all crop to a
    /// fixed frame) — `.fit` is for a caller that wants the photo's own
    /// aspect ratio to drive its size instead, uncropped.
    var contentMode: ContentMode = .fill

    var body: some View {
        if (url ?? "").isEmpty, let coordinate {
            MapSnapshotImage(coordinate: coordinate)
        } else {
            CachedAsyncImage(url: url) { placeholder }
                .aspectRatio(contentMode: contentMode)
        }
    }

    private var placeholder: some View {
        Rectangle().fill(Color.gray.opacity(0.25))
            .overlay(Image(systemName: "photo").foregroundColor(.white))
    }
}

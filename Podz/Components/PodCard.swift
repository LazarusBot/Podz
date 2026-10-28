import SwiftUI

/// Shared photo loader: remote URL via AsyncImage, gray placeholder
/// otherwise. Same pattern as AvatarView.
struct PodPhoto: View {
    var url: String?
    /// `.fill` everywhere by default (existing call sites all crop to a
    /// fixed frame) — `.fit` is for a caller that wants the photo's own
    /// aspect ratio to drive its size instead, uncropped.
    var contentMode: ContentMode = .fill

    var body: some View {
        CachedAsyncImage(url: url) { placeholder }
            .aspectRatio(contentMode: contentMode)
    }
    
    private var placeholder: some View {
        Rectangle().fill(Color.gray.opacity(0.25))
            .overlay(Image(systemName: "photo").foregroundColor(.white))
    }
}

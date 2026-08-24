import SwiftUI

struct PodCard: View {
    let pod: Pod
    var photoURL: String? = nil
    var size: CGFloat = 160
    var showLikeButton: Bool = false
    var onTap: () -> Void = {}
    @ObservedObject private var likesStore = LikesStore.shared
    @State private var showFolderPicker = false

    /// Text scales with the card so bigger cards (e.g. the 2-up "peek a
    /// third" sizing in PodSection) don't end up with captions that
    /// still look tuned for the old fixed 160pt card.
    private var scale: CGFloat { size / 160 }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                PodPhoto(url: photoURL)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.75), lineWidth: 3)
                    )
                
                if showLikeButton {
                    Button {
                        if likesStore.isLiked(pod) {
                            Task { await likesStore.removeLike(pod) }
                        } else {
                            showFolderPicker = true
                        }
                    } label: {
                        Image(systemName: likesStore.isLiked(pod) ? "heart.fill" : "heart")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(likesStore.isLiked(pod) ? .red : .white)
                            .frame(width: 25, height: 25)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5))
                    }
                    .padding(6)
                    .likeFolderPicker(for: pod, isPresented: $showFolderPicker)
                }
            }
            
            Text(pod.name)
                .font(AppFont.pillLabelBold(16 * scale))
                .foregroundColor(.black)
                .lineLimit(1)

            Text(pod.region ?? pod.country)
                .font(AppFont.itemHelper(10 * scale))
                .foregroundColor(.black)
                .lineLimit(1)

            HStack(spacing: 5 * scale) {
                Circle().fill(Color.appAvailableGreen).frame(width: 6 * scale, height: 6 * scale)
                Text("\(pod.bedsTotal ?? 0) beds available")
                    .font(AppFont.itemHelper(10 * scale))
                    .foregroundColor(.appAvailableGreen)
            }
        }
        .frame(width: size, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        
    }
}

/// "Preferred pods - <Region>" section: title + horizontal scroll of cards
/// (node 3779:2081 / 3779:2114 pattern — repeat this per region).
struct PodSection: View {
    let title: String
    let pods: [Pod]
    var photoURLs: [UUID: String] = [:]
    var showLikeButtons: Bool = false
    var onTapPod: (Pod) -> Void = { _ in }

    private let horizontalPadding: CGFloat = 24
    private let cardSpacing: CGFloat = 12
    private let peekWidth: CGFloat = 24

    /// Sized so exactly two cards fit on screen and a sliver of the
    /// third peeks in at the trailing edge, signaling the row scrolls.
    /// Derived from screen width (not GeometryReader) so it's correct
    /// on the very first frame inside this ScrollView.
    private var cardSize: CGFloat {
        (UIScreen.main.bounds.width - horizontalPadding - 2 * cardSpacing - peekWidth) / 2
    }

    /// Matches the scale PodCard applies to its own text, so the section
    /// title grows in step with the cards below it.
    private var scale: CGFloat { cardSize / 160 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.pillLabelBold(20 * scale))
                .foregroundColor(.black)
                .padding(.leading, horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: cardSpacing) {
                    ForEach(pods) { pod in
                        PodCard(pod: pod, photoURL: photoURLs[pod.id], size: cardSize, showLikeButton: showLikeButtons, onTap: { onTapPod(pod) })
                    }
                }
                .padding(.leading, horizontalPadding)
            }
        }
        .padding(.vertical, 24)
    }
}

/// Shared photo loader: remote URL via AsyncImage, gray placeholder
/// otherwise. Same pattern as AvatarView.
struct PodPhoto: View {
    var url: String?
    
    var body: some View {
        CachedAsyncImage(url: url) { placeholder }
            .aspectRatio(contentMode: .fill)
    }
    
    private var placeholder: some View {
        Rectangle().fill(Color.gray.opacity(0.25))
            .overlay(Image(systemName: "photo").foregroundColor(.white))
    }
}

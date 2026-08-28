import SwiftUI

struct PodCard: View {
    let pod: Pod
    var photoURL: String? = nil
    var size: CGFloat = 160
    var showLikeButton: Bool = false
    var onTap: () -> Void = {}
    @ObservedObject private var likesStore = LikesStore.shared
    @State private var showFolderPicker = false

    /// This card's own radius (18) is tuned for its default 160pt size —
    /// other pod photos at a different size (e.g. LennyResultCard's much
    /// bigger 345pt one) need the radius scaled by the same ratio, or the
    /// rounding reads as barely-there next to this card's.
    static func scaledCornerRadius(for photoSize: CGFloat) -> CGFloat {
        photoSize * 18 / 160
    }

    /// Text scales with the card so bigger cards (e.g. the 2-up "peek a
    /// third" sizing in PodSection) don't end up with captions that
    /// still look tuned for the old fixed 160pt card.
    private var scale: CGFloat { size / 160 }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                PodPhoto(url: photoURL)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                        // Padding moved inside the label (and the outer
                        // positioning padding dropped to match) so the
                        // icon's own visual position doesn't shift — this
                        // just grows the tappable area from ~22pt to the
                        // 44pt Apple's HIG minimum, instead of only the
                        // glyph's own tight bounds being tappable.
                        Image(systemName: likesStore.isLiked(pod) ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(likesStore.isLiked(pod) ? .red : .white)
                            .padding(11)
                            .contentShape(Rectangle())
                    }
                    .likeFolderPicker(for: pod, isPresented: $showFolderPicker)
                }
            }
            
            // Photo + name only — region and bed-availability moved out.
            // Tapping the card already opens PodDetailView, which shows
            // both (region under the map, "N beds available" beside it);
            // showing them again here was just repeating the card's own
            // "there's more, go look" job in miniature.
            // SemiBold, not Bold — Bold read too heavy for a plain card
            // caption now that it's standing alone. 5pt leading nudge
            // aligns it slightly off the photo's own edge instead of
            // sitting flush with it.
            Text(pod.name)
                .font(AppFont.pillLabelSemiBold(16 * scale))
                .foregroundColor(.black)
                .lineLimit(1)
                .padding(.leading, 5)
        }
        .frame(width: size, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        
    }
}

/// Reports the width actually proposed to `PodSection` — same
/// background-GeometryReader-plus-preference trick `HomeSearchRow` uses
/// for its Save button (see `WidthPreferenceKey` in CategoryScroller.swift)
/// — so `cardSize` tracks the real available width (correct in Slide
/// Over/Split View on iPad) instead of `UIScreen.main.bounds.width`
/// (the full physical screen, wrong the moment the app isn't using all
/// of it).
private struct SectionWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = UIScreen.main.bounds.width
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// "Preferred pods — <Region>" section: title + horizontal scroll of cards
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

    // Seeded from UIScreen so the very first frame (before the
    // GeometryReader below reports back) is still correctly sized rather
    // than starting at 0.
    @State private var availableWidth: CGFloat = UIScreen.main.bounds.width

    /// Sized so exactly two cards fit on screen and a sliver of the
    /// third peeks in at the trailing edge, signaling the row scrolls.
    private var cardSize: CGFloat {
        (availableWidth - horizontalPadding - 2 * cardSpacing - peekWidth) / 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Fixed size, not scaled with cardSize — a section title
            // shrinking on smaller phones (and ballooning on iPads) reads
            // as a typography bug, not a considered choice. PodCard's own
            // internal text still scales with its own card size, which is
            // the legitimate case: that's a card literally getting
            // bigger, not a heading responding to a different screen.
            Text(title)
                .font(AppFont.pillLabelBold(20))
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
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: SectionWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(SectionWidthPreferenceKey.self) { availableWidth = $0 }
    }
}

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

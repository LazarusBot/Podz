import SwiftUI

/// The photo pager's dots: a small row at the bottom of the photo, the current
/// photo's dot solid and the others faint. Nothing for a single photo.
struct PodPhotoDots: View {
    let photoCount: Int
    let currentIndex: Int

    private let dotSize: CGFloat = 8
    private let maxDots = 7

    private var dotCount: Int { photoCount > 1 ? min(photoCount, maxDots) : 0 }

    /// With more photos than dots, the dots stand for evenly spaced slices
    /// of the whole set.
    private var activeDot: Int {
        guard dotCount > 0 else { return 0 }
        if photoCount <= maxDots { return min(currentIndex, dotCount - 1) }
        return min(currentIndex * dotCount / photoCount, dotCount - 1)
    }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(index == activeDot ? 1 : 0.45)
            }
        }
        .animation(.easeOut(duration: AppMotion.snappy), value: activeDot)
        .accessibilityHidden(true)
    }
}

import SwiftUI

/// Lenny's round badge, half over the photo's bottom edge, with the photo
/// pager's dots fanned on an arc above it (Paper "DetailView" frames).
/// Dots are in the ground color so they read as bites out of the photo
/// around the badge; the current photo's dot is solid, the others faint.
struct PodDetailBadge: View {
    let photoCount: Int
    let currentIndex: Int

    private let badgeSize: CGFloat = 56
    private let dotSize: CGFloat = 10
    private let arcRadius: CGFloat = 42
    private let maxDots = 5

    private var dotCount: Int { photoCount > 1 ? min(photoCount, maxDots) : 0 }

    /// With more photos than dots, the dots stand for evenly spaced slices
    /// of the whole set.
    private var activeDot: Int {
        guard dotCount > 0 else { return 0 }
        if photoCount <= maxDots { return min(currentIndex, dotCount - 1) }
        return min(currentIndex * dotCount / photoCount, dotCount - 1)
    }

    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                let angle = Angle.degrees(90 + (Double(index) - Double(dotCount - 1) / 2) * 36)
                Circle()
                    .fill(Color.homeBackground)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(index == activeDot ? 1 : 0.4)
                    .offset(
                        x: arcRadius * CGFloat(cos(angle.radians)),
                        y: -arcRadius * CGFloat(sin(angle.radians))
                    )
            }

            Image("lenny")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundColor(.homeBackground)
                .frame(width: badgeSize, height: badgeSize)
                .background(Color.homeText, in: Circle())
                .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 3))
        }
        .frame(width: badgeSize, height: badgeSize)
        .animation(.easeOut(duration: AppMotion.snappy), value: activeDot)
        .accessibilityHidden(true)
    }
}

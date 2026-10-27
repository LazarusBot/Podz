import SwiftUI

/// The shared layout of every onboarding step that has a photo: photo on
/// top (it takes whatever height the text and controls below don't, so it
/// shrinks gracefully when the keyboard is up), then a centered title and
/// subtitle, then the step's own controls.
struct OnboardingHeroScreen<Bottom: View>: View {
    enum PhotoStyle {
        /// Inset rounded card — the email and code steps.
        case card
        /// Edge-to-edge, rounded only along the bottom — the intro steps.
        case bleed
    }

    let photo: String
    var photoStyle: PhotoStyle = .bleed
    let title: String
    let subtitle: String
    /// Lenny's face, half-overlapping the photo's bottom edge.
    var showsLennyBadge = false
    @ViewBuilder var bottom: () -> Bottom

    private let badgeSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            hero
                .frame(maxHeight: .infinity)

            VStack(spacing: photoStyle == .card ? 18 : 23) {
                Text(title)
                    .font(OnboardingFont.title)
                    .foregroundColor(.onbText)

                Text(subtitle)
                    .font(photoStyle == .card ? OnboardingFont.compact : OnboardingFont.body)
                    .lineSpacing(photoStyle == .card ? 0 : 5)
                    .foregroundColor(.onbSubtitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: photoStyle == .card ? 215 : 329)
            }
            .padding(.top, textTopPadding)
            .padding(.horizontal, 32)

            bottom()
                .padding(.top, 24)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.onbBackground.ignoresSafeArea())
    }

    private var textTopPadding: CGFloat {
        switch photoStyle {
        case .card: 44
        case .bleed: showsLennyBadge ? 29 + badgeSize / 2 : 29
        }
    }

    @ViewBuilder
    private var hero: some View {
        switch photoStyle {
        case .card:
            Color.clear
                .overlay { photoImage }
                .clipShape(RoundedRectangle(cornerRadius: 53, style: .continuous))
                .padding(.horizontal, 21)
                .padding(.top, 8)
        case .bleed:
            Color.clear
                .overlay { photoImage }
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 75, bottomTrailingRadius: 75, style: .continuous))
                .overlay(alignment: .bottom) {
                    if showsLennyBadge { lennyBadge.offset(y: badgeSize / 2) }
                }
                .ignoresSafeArea(edges: .top)
        }
    }

    private var photoImage: some View {
        Image(photo)
            .resizable()
            .scaledToFill()
    }

    private var lennyBadge: some View {
        Image("lenny")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .foregroundColor(.onbBackground)
            .frame(width: badgeSize, height: badgeSize)
            .background(Color.onbText, in: Circle())
            .overlay(Circle().strokeBorder(Color.onbBackground, lineWidth: 3))
            .accessibilityHidden(true)
    }
}

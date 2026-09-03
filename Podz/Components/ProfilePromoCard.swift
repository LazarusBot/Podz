import SwiftUI

/// "Make your place a Podz" promo card (node 3827:1459).
/// Figma's own height (99) read as too small in practice — sized up to
/// 124 (text/padding bumped to match), everything else still the exact
/// Figma values: corner radius 15, border 0.5px #E1E1E1, shadow
/// "1px 3px 4px rgba(166,166,166,0.1)" (= AppShadow.panel), outer padding
/// 24 horizontal / 31 vertical around the card itself.
struct ProfilePromoCard: View {
    var backgroundImageName: String = "Pod"
    var onTap: () -> Void = {}
    
    var imageScale: CGFloat = 1.4
    var imageOffset: CGSize = .init(width: 110, height: 0)
    
    /// "Make your place a Podz." with only "Podz" underlined. Built via
    /// string interpolation — an AttributedString segment keeps its own
    /// attributes when spliced into another one this way.
    private var promoTitle: AttributedString {
        var underline = AttributeContainer()
        underline.underlineStyle = .single

        let prefix = AttributedString("Make your place a ")
        let podz = AttributedString("Podz", attributes: underline)
        let suffix = AttributedString(".")

        return prefix + podz + suffix
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .leading) {
                // Photo ancrée à droite, largeur fixe (pas toute la carte)
                Group {
                    if UIImage(named: backgroundImageName) != nil {
                        Image(backgroundImageName)
                            .resizable()
                            .scaleEffect(imageScale)
                            .offset(imageOffset)
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.25))
                    }
                }
                .frame(width: 345, height: 124)
                .clipped()
                .frame(maxWidth: .infinity, alignment: .trailing)

                // Fondu blanc qui recouvre la gauche et dévoile l'image à droite
                LinearGradient(
                    stops: [
                        .init(color: Color.appHomeBackground.opacity(0), location: 0),
                        .init(color: Color.appHomeBackground, location: 0.66),
                        .init(color: Color.appHomeBackground, location: 1)
                    ],
                    startPoint: .trailing, endPoint: .leading
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(promoTitle)
                        .font(AppFont.pillLabel(18))
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Set up easily and start earning from your home.")
                        Text("It's free.")
                    }
                    .font(AppFont.itemHelper(11))
                    .foregroundColor(.black)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
                .frame(maxWidth: 266, alignment: .leading)
            }
        }
        // Plain Button here defaulted to the system's automatic press
        // state, which dims custom content toward black — reads as a
        // dark layer flashing over the whole card on tap. A custom style
        // replaces it with a deliberate scale-down + a light haptic,
        // rather than just killing the dimming and leaving no feedback
        // at all (same reasoning as LikesFolderCard's own NoFadeButtonStyle,
        // which only solves the first half of that).
        .buttonStyle(TapScaleButtonStyle())
        .frame(height: 124)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.appHomeBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Color.appBorder, lineWidth: 0.5))
        .padding(.horizontal, 24)
        .padding(.vertical, 31)
    }
}

#Preview {
    ProfilePromoCard()
        .background(Color.appHomeBackground)
}

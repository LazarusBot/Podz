import SwiftUI

/// Generic photo-banner promo card (node 3827:1459) — originally built
/// just for "become a host," now the shared shell behind every card of
/// this shape (invite friends, complete your profile, share a trip).
/// Figma's own height (99) read as too small in practice — sized up to
/// 124 (text/padding bumped to match), everything else still the exact
/// Figma values: corner radius 15, border 0.5px #E1E1E1, shadow
/// "1px 3px 4px rgba(166,166,166,0.1)" (= AppShadow.panel), outer padding
/// 24 horizontal / 31 vertical around the card itself.
struct PromoCard: View {
    var backgroundImageName: String
    var title: AttributedString
    /// Stacked with zero spacing between lines, same as the original
    /// "Set up easily.../It's free." two-liner — a caller wanting a
    /// single-sentence subtitle just passes one element.
    var subtitleLines: [String]
    var onTap: () -> Void = {}

    var imageScale: CGFloat = 1.4
    var imageOffset: CGSize = .init(width: 110, height: 0)

    /// Builds "<prefix><underlined word/phrase><suffix>" — the one-word-
    /// underlined title treatment every promo card uses. `AttributedString`
    /// segments keep their own attributes when spliced into another one
    /// this way.
    static func title(prefix: String, underlined: String, suffix: String = ".") -> AttributedString {
        var underline = AttributeContainer()
        underline.underlineStyle = .single
        return AttributedString(prefix) + AttributedString(underlined, attributes: underline) + AttributedString(suffix)
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
                    Text(title)
                        .font(AppFont.pillLabel(18))
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(subtitleLines, id: \.self) { line in
                            Text(line)
                        }
                    }
                    // Real Inter, Regular weight — see
                    // `ProfileRows.swift`'s `ProfileAccountRow` for why
                    // this isn't `AppFont.itemHelper`.
                    .font(AppFont.regularLabel(11))
                    .foregroundColor(.black)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
                .frame(maxWidth: 266, alignment: .leading)
            }
            .frame(height: 124)
            // Background/clip/border live inside the button's label now,
            // not after `.buttonStyle()` — `TapScaleButtonStyle`'s
            // `.scaleEffect` only wraps `configuration.label` (everything
            // in this closure), so anything applied *after* `.buttonStyle`
            // sits outside that scope and never actually scales. With the
            // card's own background/clip/border out there, only the raw
            // content (image/gradient/text) was shrinking on press while
            // the card's own frame stayed put — moving them in here means
            // the whole card scales as one piece.
            .background(
                RoundedRectangle(cornerRadius: AppRadius.r15)
                    .fill(Color.appHomeBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r15))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.r15).strokeBorder(Color.appBorder, lineWidth: 0.5))
            // Pins the tappable region to exactly the visible 124pt-tall
            // card — without this, `Button`'s default hit-testing was
            // extending down into its own `.padding(.vertical, 31)`
            // below (applied outside, after this closure), which sits
            // directly against whatever sits right underneath it — a tap
            // meant for the top of that content could land on this card
            // instead. Same fix as `ProfileAccountRow`/`ProfileMenuRow`,
            // opposite direction (their bug was a dead zone *inside* the
            // button; this one was the button's own area reaching
            // *outside* itself).
            .contentShape(Rectangle())
        }
        // Plain Button here defaulted to the system's automatic press
        // state, which dims custom content toward black — reads as a
        // dark layer flashing over the whole card on tap. A custom style
        // replaces it with a deliberate scale-down + a light haptic,
        // rather than just killing the dimming and leaving no feedback
        // at all (same reasoning as LikesFolderCard's own NoFadeButtonStyle,
        // which only solves the first half of that).
        .buttonStyle(TapScaleButtonStyle())
        .padding(.horizontal, 24)
        .padding(.vertical, 31)
    }
}

#Preview {
    VStack(spacing: 0) {
        PromoCard(
            backgroundImageName: "Pod",
            title: PromoCard.title(prefix: "Make your place a ", underlined: "Podz"),
            subtitleLines: ["Set up easily and start earning from your home.", "It's free."]
        )
        PromoCard(
            backgroundImageName: "Hutte2",
            title: PromoCard.title(prefix: "Plan trips with your ", underlined: "friends"),
            subtitleLines: ["Find people you know and see where they're headed."]
        )
    }
    .background(Color.appHomeBackground)
}

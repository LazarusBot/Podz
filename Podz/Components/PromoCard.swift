import SwiftUI

/// Generic promo card (node 3827:1459, photo-style node 4642:766) — the
/// shared shell behind every card of this shape. Started as a single
/// look (photo anchored right, fading into a light panel — `.light`
/// below), then grew a second `.photo` form for banners that need to
/// read as live/personalized content (e.g. "continue a previous
/// search") rather than an evergreen feature ad — a full-bleed, blurred
/// photo reads as "a real place," the light panel reads as "an app
/// feature." Both styles share one text hierarchy (Darker Grotesque
/// Bold title, Inter Regular subtitle/caption below it) and the same
/// outer chrome (corner radius 15, border 0.5px #E1E1E1, shadow
/// "1px 3px 4px rgba(166,166,166,0.1)" = AppShadow.panel, 124pt tall —
/// Figma's own 99 read as too small in practice — outer padding 24
/// horizontal / 31 vertical), so a caller only ever has to pick a
/// `style`, not rebuild the frame or guess at a new type scale.
struct PromoCard: View {
    enum Style {
        /// Original look: fixed-width photo anchored to the trailing
        /// edge, fading into a plain panel on the leading edge where
        /// the text sits. Reads as a static feature/marketing slot.
        case light
        /// Node 4642:766: full-bleed, blurred photo, white text
        /// directly on top, small "open" affordance top-trailing.
        /// Reads as dynamic, personalized content.
        case photo
    }

    var style: Style = .light
    var backgroundImageName: String
    var title: AttributedString
    /// Stacked with zero spacing between lines, same as the original
    /// "Set up easily.../It's free." two-liner — a caller wanting a
    /// single-sentence subtitle just passes one element.
    var subtitleLines: [String]
    /// Small de-emphasized eyebrow label above the title (e.g. a date
    /// range) — only `.photo` renders it today, but it's a general
    /// field rather than a `.photo`-only parameter so a future form can
    /// pick it up without another API change.
    var caption: String? = nil
    var onTap: () -> Void = {}

    var imageScale: CGFloat = 1.4
    var imageOffset: CGSize = .init(width: 110, height: 0)

    /// Builds "<prefix><underlined word/phrase><suffix>" — the one-word-
    /// underlined title treatment the `.light` cards use. `AttributedString`
    /// segments keep their own attributes when spliced into another one
    /// this way. `.photo` cards tend to use a plain, unstyled title
    /// instead (node 4642:766's isn't underlined), so this is opt-in,
    /// not required.
    static func title(prefix: String, underlined: String, suffix: String = ".") -> AttributedString {
        var underline = AttributeContainer()
        underline.underlineStyle = .single
        return AttributedString(prefix) + AttributedString(underlined, attributes: underline) + AttributedString(suffix)
    }

    var body: some View {
        Button(action: onTap) {
            Group {
                switch style {
                case .light: lightContent
                case .photo: photoContent
                }
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

    private var lightContent: some View {
        ZStack(alignment: .leading) {
            // Photo anchored trailing, fixed width (not the full card).
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

            // Fade from the plain panel color (leading) into the photo
            // (trailing).
            LinearGradient(
                stops: [
                    .init(color: Color.appHomeBackground.opacity(0), location: 0),
                    .init(color: Color.appHomeBackground, location: 0.66),
                    .init(color: Color.appHomeBackground, location: 1)
                ],
                startPoint: .trailing, endPoint: .leading
            )

            VStack(alignment: .leading, spacing: 6) {
                // Darker Grotesque Bold — the same weight `AppFont`'s own
                // doc comment calls out for "section titles," which is
                // what a promo card headline is. Was `pillLabel` (Black)
                // plus a `.fontWeight(.bold)` that did nothing — SwiftUI
                // doesn't reweight a `.custom` font via `.fontWeight()`,
                // so it was silently rendering as Black, one step heavier
                // than intended and mismatched with `.photo`'s own title.
                Text(title)
                    .font(AppFont.pillLabelBold(18))
                    .foregroundColor(.black)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(subtitleLines, id: \.self) { line in
                        Text(line)
                    }
                }
                // Real Inter, Regular weight — see
                // `ProfileRows.swift`'s `ProfileAccountRow` for why
                // this isn't `AppFont.itemHelper`. Same size/weight as
                // `.photo`'s own subtitle — one shared text hierarchy
                // for the whole component, not one per style.
                .font(AppFont.regularLabel(11))
                .foregroundColor(.black)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .frame(maxWidth: 266, alignment: .leading)
        }
    }

    private var photoContent: some View {
        ZStack(alignment: .leading) {
            Group {
                if UIImage(named: backgroundImageName) != nil {
                    Image(backgroundImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.25))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Just enough to soften the photo for text legibility, not
            // enough to read as an actual blur effect. Scaled up before
            // blurring so the blur's own (much smaller, at this radius)
            // edge falloff never reveals transparent/background pixels
            // at the card's border — then clipped back down to the
            // card's actual bounds.
            .scaleEffect(1.05)
            .blur(radius: 2)
            .clipped()

            VStack(alignment: .leading, spacing: 5) {
                // Same two-tier type system as `.light`: Darker Grotesque
                // Bold for the headline, real Inter Regular for
                // everything below it, differentiated by size + opacity
                // rather than by piling on more font weights. The
                // caption sits a step below the subtitle on both — same
                // family/weight, just smaller and more muted.
                if let caption {
                    Text(caption)
                        .font(AppFont.regularLabel(8))
                        .underline()
                        .foregroundColor(.white.opacity(0.6))
                }
                Text(title)
                    .font(AppFont.pillLabelBold(18))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(subtitleLines, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(AppFont.regularLabel(11))
                .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: 210, alignment: .leading)

            HStack {
                Spacer()
                VStack {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
            }
            .padding(14)
        }
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
        PromoCard(
            style: .photo,
            backgroundImageName: "Hutte",
            title: AttributedString("Slovénia is waiting on you!"),
            subtitleLines: ["Open the available pods for Slovénia."],
            caption: "5-7 September"
        )
    }
    .background(Color.appHomeBackground)
}

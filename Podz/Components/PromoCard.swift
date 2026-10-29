import SwiftUI

/// Generic promo card (node 3827:1459) — the shared shell behind every
/// card of this shape. Started as a single look (photo anchored right,
/// fading into a light panel — `.light` below), then grew two more
/// forms for banners that need to read as live/personalized content
/// (e.g. "continue a previous search") rather than an evergreen feature
/// ad: `.photo` (full-bleed, blurred photo, node 4642:766) and `.stack`
/// (a fanned cluster of small photos on a plain panel, node 4642:753) —
/// Figma shows both as candidates for the same search-continuation
/// banner, kept side by side here so they can be compared on-device
/// before picking one. All three share one text hierarchy (Darker
/// Grotesque Bold title, Inter Regular subtitle/caption below it) and
/// the same outer chrome (corner radius 15, border 0.5px #E1E1E1,
/// shadow "1px 3px 4px rgba(166,166,166,0.1)" = AppShadow.panel, 124pt
/// tall — Figma's own 99 read as too small in practice — outer padding
/// 24 horizontal / 31 vertical), so a caller only ever has to pick a
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
        /// Node 4642:753: plain panel background with a small fanned
        /// cluster of photos (`backgroundImageName` in front, centered
        /// and unrotated; `secondaryImageNames` behind it, tilted ±6°)
        /// instead of one large photo. Reads as "a few specific places,"
        /// closer to a results preview than a single hero shot.
        case stack
    }

    var style: Style = .light
    var backgroundImageName: String
    /// `.stack` only: the two smaller, tilted photos behind the front
    /// one. Ignored by `.light`/`.photo`.
    var secondaryImageNames: [String] = []
    var title: AttributedString
    /// Stacked with zero spacing between lines, same as the original
    /// "Set up easily.../It's free." two-liner — a caller wanting a
    /// single-sentence subtitle just passes one element.
    var subtitleLines: [String]
    /// Small de-emphasized eyebrow label above the title (e.g. a date
    /// range) — every style renders it, muted gray on `.light`/`.stack`,
    /// muted white on `.photo`.
    var caption: String? = nil
    var onTap: () -> Void = {}

    var imageScale: CGFloat = 1.4
    var imageOffset: CGSize = .init(width: 110, height: 0)

    /// `.stack` only: which of the cluster's photos is currently in front.
    @State private var frontIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let clusterInterval: Double = 1.8

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
                case .stack: stackContent
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
        // at all.
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
                if let caption {
                    Text(caption)
                        .font(AppFont.regularLabel(8))
                        .underline()
                        .foregroundColor(.appTextMuted)
                }

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

    private var stackContent: some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 6) {
                if let caption {
                    Text(caption)
                        .font(AppFont.regularLabel(8))
                        .underline()
                        .foregroundColor(.appTextMuted)
                }
                // `.fixedSize` so the headline lays out at its natural
                // single-line width instead of wrapping inside the
                // `maxWidth` below — there's room for it next to the
                // photo cluster, the subtitle is what should wrap if
                // anything does.
                Text(title)
                    .font(AppFont.pillLabelBold(18))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(subtitleLines, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(AppFont.regularLabel(11))
                .foregroundColor(.black)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: 190, alignment: .leading)

            HStack {
                Spacer()
                photoCluster
                    .padding(.trailing, 22)
            }
        }
    }

    /// Three fanned, overlapping thumbnails (node 4642:753's own
    /// "image 3" / "image 50" / "image 51") — the front one centered
    /// and unrotated, the two behind it smaller and tilted ±6°, same
    /// idea as `PostCard`/`PodDetailView`'s own fanned "coming next"
    /// stacks. Loops forever: every `clusterInterval` seconds the front
    /// photo drops to the back and the next one springs forward, so the
    /// banner has some movement to it. Each photo keeps its identity
    /// (ForEach over indices) and only its slot changes, which is what
    /// lets SwiftUI animate the move instead of cross-fading.
    private var photoCluster: some View {
        let names = clusterImageNames
        return ZStack {
            ForEach(names.indices, id: \.self) { index in
                let slot = (index - frontIndex + names.count) % names.count
                stackThumbnail(names[index], size: slot == 0 ? 76 : 64)
                    .rotationEffect(.degrees(slot == 0 ? 0 : (slot == 1 ? -6 : 6)))
                    .offset(x: slot == 0 ? 0 : (slot == 1 ? -16 : 16))
                    .zIndex(Double(names.count - slot))
            }
        }
        .frame(width: 108, height: 88)
        .task(id: names.count) { await cycleFrontPhoto(count: names.count) }
    }

    private var clusterImageNames: [String] {
        [backgroundImageName] + secondaryImageNames
    }

    private func cycleFrontPhoto(count: Int) async {
        guard count > 1, !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.clusterInterval))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                frontIndex = (frontIndex + 1) % count
            }
        }
    }

    private func stackThumbnail(_ name: String, size: CGFloat) -> some View {
        Group {
            if UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color.gray.opacity(0.25))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.appHomeBackground, lineWidth: 2))
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
        PromoCard(
            style: .stack,
            backgroundImageName: "Hutte",
            secondaryImageNames: ["Hutte2", "Hutte3"],
            title: AttributedString("Slovénia is waiting on you!"),
            subtitleLines: ["Open the available pods for Slovénia."],
            caption: "5-7 September"
        )
    }
    .background(Color.appHomeBackground)
}

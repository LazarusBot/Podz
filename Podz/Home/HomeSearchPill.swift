import SwiftUI

/// "Search a region or ask Lenny". Two modes:
///
/// - **Classic search** (tapping the bar): a plain pill field that filters
///   the cards. Nothing moves.
/// - **Lenny** (tapping the round mark; Paper "Home2" frames): the bar
///   inverts, Lenny rolls from the trailing end to the leading end and its
///   disc melts into the bar so only the eyes stay visible, and
///   the field asks for a route. Leaving the field rolls it back.
struct HomeSearchPill: View {
    /// What the field currently edits — the screen swaps this between the
    /// classic query and the Lenny route.
    @Binding var text: String
    @Binding var isLennyMode: Bool
    /// Owned by the screen, so a tap outside can drop focus from there.
    var isFocused: FocusState<Bool>.Binding
    /// Called on the keyboard's Search key.
    var onSubmit: () -> Void = {}

    private let buttonSize: CGFloat = 40
    /// Lenny's face fills the round button; while the button opens into "Ask
    /// Lenny" it steps down so the eyes stay small beside the words.
    private var faceSize: CGFloat { offersAsk ? 22 : buttonSize }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let inset: CGFloat = 9
    /// Lenny's button with its label ("Ask Lenny"): it opens up to this width
    /// while the search field has the keyboard, and is the round mark otherwise.
    private let askWidth: CGFloat = 118

    /// Searching in the plain field (not in Lenny mode): Lenny is offered.
    private var offersAsk: Bool { isFocused.wrappedValue && !isLennyMode }

    var body: some View {
        ZStack(alignment: isLennyMode ? .leading : .trailing) {
            field
            lennyMark
                .padding(inset)
        }
        .frame(height: 60)
        .background { barBackground }
        .contentShape(Capsule())
        .onTapGesture { isFocused.wrappedValue = true }
        .animation(.smooth(duration: 0.4), value: isLennyMode)
        .animation(.smooth(duration: 0.35), value: isFocused.wrappedValue)
    }

    private var field: some View {
        TextField(
            "",
            text: $text,
            prompt: T(isLennyMode ? "Chamonix to Zermatt in 5 days" : "Search a region")
                .foregroundColor(isLennyMode ? .homeSubtitleOnInverse : .homeSubtitle)
        )
        .font(AppFont.regularLabel(14))
        .foregroundColor(isLennyMode ? .homeBackground : .homeText)
        // The caret follows the tint: against the inverted bar it has to
        // be the ground color.
        .tint(isLennyMode ? .homeBackground : .homeText)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .focused(isFocused)
        .onSubmit(onSubmit)
        // Room for the mark on whichever side it's on, plus the gap.
        .padding(.leading, isLennyMode ? inset + buttonSize + 20 : 28)
        .padding(.trailing, isLennyMode ? 28 : inset + (offersAsk ? askWidth : buttonSize) + 8)
    }

    private var buttonWidth: CGFloat { offersAsk ? askWidth : buttonSize }

    private var buttonAlignment: Alignment { isLennyMode ? .leading : .trailing }

    /// The bar and the round button on it, with **Lenny's eyes cut out of
    /// both**: the holes show the page behind the pill, whatever the bar's
    /// color (the bar is `homePill`, or `homeText` in Lenny mode where the button
    /// melts into it). The button's face is laid out here exactly as in
    /// `lennyMark`, so the holes follow it as it opens, rolls and slides.
    private var barBackground: some View {
        ZStack(alignment: buttonAlignment) {
            Capsule().fill(isLennyMode ? Color.homeText : Color.homePill)
            Capsule().fill(Color.homeText)
                .frame(width: buttonWidth, height: buttonSize)
                .padding(inset)
        }
        .mask {
            ZStack(alignment: buttonAlignment) {
                Rectangle()
                buttonLayout(isCutout: true)
                    .foregroundColor(.black)
                    .blendMode(.destinationOut)
                    .padding(inset)
            }
            .compositingGroup()
        }
    }

    /// The button's content: the face (a hole in the bar behind) and, once the
    /// button opens, the words. Drawn twice with the same layout: with
    /// `isCutout` the face is what is drawn (into the mask), without it the
    /// words are (on the button).
    private func buttonLayout(isCutout: Bool) -> some View {
        HStack(spacing: offersAsk ? 10 : 0) {
            // The face is drawn at the size of a disc.
            Image("lenny")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: faceSize, height: faceSize)
                // The eyes sit right in their disc: nudged left, so there
                // is air before "Ask Lenny".
                .offset(x: offersAsk ? -3 : 0)
                // One full turn as it slides across: the "roll" (Reduce
                // Motion: it only slides).
                .rotationEffect(.degrees(isLennyMode && !reduceMotion ? 360 : 0))
                .opacity(isCutout ? 1 : 0)

            if offersAsk {
                T("Ask Lenny")
                    .font(AppFont.semiBoldLabel(13))
                    .lineLimit(1)
                    .fixedSize()
                    .opacity(isCutout ? 0 : 1)
                    .transition(.opacity)
            }
        }
        .frame(width: buttonWidth, height: buttonSize)
    }

    /// Lenny's button. At rest it is the round mark. When you start searching
    /// in the field it opens into "Ask Lenny" on a solid capsule, an offer
    /// at the moment you're looking for a pod. In Lenny mode it is the round
    /// mark again, rolled to the leading end and melted into the bar so only
    /// the eyes stay visible. The capsule and the eyes' holes are drawn behind
    /// (`barBackground`); this is the tap target and the words.
    private var lennyMark: some View {
        Button {
            isLennyMode.toggle()
            isFocused.wrappedValue = true
        } label: {
            buttonLayout(isCutout: false)
                .foregroundColor(.homeBackground)
                .contentShape(Capsule())
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel(tr("Ask Lenny"))
        .accessibilityHint(tr("Describe your trip and Lenny finds the huts"))
        .accessibilityAddTraits(isLennyMode ? .isSelected : [])
    }
}

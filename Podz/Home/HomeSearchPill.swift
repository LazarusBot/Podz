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
    /// Lenny's body in Lenny mode (no eyes), inside that 40: the Lenny screen's
    /// bar uses the same size so the hand-over is seamless.
    static let blobSize: CGFloat = 28
    /// A tap on the button: his body wobbles.
    @State private var blobBurst = 0
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
        .background(isLennyMode ? Color.homeText : Color.homePill, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { isFocused.wrappedValue = true }
        // Each letter typed to Lenny makes his body react.
        .onChange(of: text) { _, _ in if isLennyMode { blobBurst += 1 } }
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

    /// The face and, once the button opens, the words, laid out in a frame the
    /// size of the button: they are what is cut out of the capsule. `showsFace`
    /// is off in Lenny mode, where Lenny has no eyes (see `buttonCapsule`).
    private func buttonContent(showsFace: Bool) -> some View {
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
                .opacity(showsFace ? 1 : 0)

            if offersAsk {
                T("Ask Lenny")
                    .font(AppFont.semiBoldLabel(13))
                    .lineLimit(1)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        .frame(width: buttonWidth, height: buttonSize)
    }

    /// The `homeText` capsule with **Lenny's eyes (and the words) cut out of
    /// it**, so the bar shows through them. In Lenny mode the button melts into
    /// the bar (the same color) and Lenny **has no eyes**: his body, a blob in the
    /// ground's color, sits in its place and reshapes while you type and when you
    /// tap it (`LennyBlob`).
    private var buttonCapsule: some View {
        Capsule()
            .fill(Color.homeText)
            .frame(width: buttonWidth, height: buttonSize)
            .mask {
                ZStack {
                    Rectangle()
                    buttonContent(showsFace: !isLennyMode)
                        .foregroundColor(.black)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .overlay {
                // In Lenny mode the button melts into the bar and Lenny has no eyes:
                // his body, a circle in the ground's color, reshapes as you type.
                LennyBlob(color: .homeBackground, burst: blobBurst)
                    .frame(width: Self.blobSize, height: Self.blobSize)
                    .opacity(isLennyMode ? 1 : 0)
            }
            .contentShape(Capsule())
    }

    /// Lenny's button. At rest it is the round mark. When you start searching
    /// in the field it opens into "Ask Lenny" on a solid capsule, an offer
    /// at the moment you're looking for a pod. In Lenny mode it is the round
    /// mark again, rolled to the leading end and melted into the bar so only
    /// the eyes stay visible.
    private var lennyMark: some View {
        Button {
            isLennyMode.toggle()
            blobBurst += 1
            isFocused.wrappedValue = true
        } label: {
            buttonCapsule
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel(tr("Ask Lenny"))
        .accessibilityHint(tr("Describe your trip and Lenny finds the huts"))
        .accessibilityAddTraits(isLennyMode ? .isSelected : [])
    }
}

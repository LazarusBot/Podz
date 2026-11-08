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
    /// Lenny's face inside that button (see `LennySearchScreen.routePill`, which
    /// takes over from here and must match).
    static let faceSize: CGFloat = 28
    private var faceSize: CGFloat { Self.faceSize }
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

    /// Lenny's button. At rest it is the round mark. When you start searching
    /// in the field it opens into "Ask Lenny" on a solid capsule, an offer
    /// at the moment you're looking for a pod. In Lenny mode it is the round
    /// mark again, rolled to the leading end and melted into the bar so only
    /// the eyes stay visible.
    private var lennyMark: some View {
        Button {
            isLennyMode.toggle()
            isFocused.wrappedValue = true
        } label: {
            HStack(spacing: 4) {
                // The face is drawn at the size of a disc: smaller than the
                // button, so the eyes stay small in it.
                Image("lenny")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: faceSize, height: faceSize)
                    // One full turn as it slides across: the "roll" (Reduce
                    // Motion: it only slides).
                    .rotationEffect(.degrees(isLennyMode && !reduceMotion ? 360 : 0))

                if offersAsk {
                    T("Ask Lenny")
                        .font(AppFont.semiBoldLabel(13))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .foregroundColor(.homeBackground)
            .frame(width: offersAsk ? askWidth : buttonSize, height: buttonSize)
            .background(Color.homeText, in: Capsule())
            .clipped()
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel(tr("Ask Lenny"))
        .accessibilityHint(tr("Describe your trip and Lenny finds the huts"))
        .accessibilityAddTraits(isLennyMode ? .isSelected : [])
    }
}

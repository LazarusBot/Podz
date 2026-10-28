import SwiftUI

/// "Search a region or ask Lenny". Two modes:
///
/// - **Classic search** (tapping the bar): a plain pill field that filters
///   the cards. Nothing moves.
/// - **Lenny** (tapping the round mark; Paper "Home2" frames): the bar
///   inverts, Lenny rolls from the trailing end to the leading end and its
///   disc melts into the bar so only the eyes and mouth stay visible, and
///   the field asks for a route. Leaving the field rolls it back.
struct HomeSearchPill: View {
    /// What the field currently edits — the screen swaps this between the
    /// classic query and the Lenny route.
    @Binding var text: String
    @Binding var isLennyMode: Bool
    /// Owned by the screen, so a tap outside can drop focus from there.
    var isFocused: FocusState<Bool>.Binding

    private let buttonSize: CGFloat = 40
    private let inset: CGFloat = 9

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
    }

    private var field: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(isLennyMode ? "Chamonix to Zermatt in 5 days" : "Search a region or ask Lenny")
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
        // Room for the mark on whichever side it's on, plus the gap.
        .padding(.leading, isLennyMode ? inset + buttonSize + 20 : 28)
        .padding(.trailing, isLennyMode ? 28 : inset + buttonSize + 8)
    }

    /// Same disc and glyph colors in both modes — it's the bar that
    /// changes, which is what makes the disc disappear into it.
    private var lennyMark: some View {
        Button {
            isLennyMode.toggle()
            isFocused.wrappedValue = true
        } label: {
            Image("lenny")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(.homeBackground)
                .frame(width: buttonSize, height: buttonSize)
                .background(Color.homeText, in: Circle())
                // One full turn as it slides across — the "roll".
                .rotationEffect(.degrees(isLennyMode ? 360 : 0))
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel("Ask Lenny")
        .accessibilityAddTraits(isLennyMode ? .isSelected : [])
    }
}

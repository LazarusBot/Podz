import SwiftUI

/// "Search a region or ask Lenny" — a pill field with Lenny's round mark.
/// Focusing the field (Paper "Home2" frames) inverts the pill and rolls
/// Lenny from the trailing end to the leading end; the mark's disc matches
/// the bar's new color, so only its eyes and mouth stay visible. Losing
/// focus rolls it back to where it started.
struct HomeSearchPill: View {
    @Binding var text: String
    /// Owned by the screen, so a tap outside can drop focus from there.
    var isFocused: FocusState<Bool>.Binding

    private let buttonSize: CGFloat = 40
    private let inset: CGFloat = 9

    var body: some View {
        ZStack(alignment: focused ? .leading : .trailing) {
            field
            lennyMark
                .padding(inset)
        }
        .frame(height: 60)
        .background(focused ? Color.homeText : Color.homePill, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { isFocused.wrappedValue = true }
        .animation(.smooth(duration: 0.4), value: focused)
    }

    private var focused: Bool { isFocused.wrappedValue }

    private var field: some View {
        TextField(
            "",
            text: $text,
            prompt: Text("Search a region or ask Lenny")
                .foregroundColor(focused ? .homeSubtitleOnInverse : .homeSubtitle)
        )
        .font(AppFont.regularLabel(14))
        .foregroundColor(focused ? .homeBackground : .homeText)
        // The caret follows the tint: against the inverted bar it has to
        // be the ground color.
        .tint(.homeBackground)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .focused(isFocused)
        // Room for the mark on whichever side it's on, plus the gap.
        .padding(.leading, focused ? inset + buttonSize + 20 : 28)
        .padding(.trailing, focused ? 28 : inset + buttonSize + 8)
    }

    /// Same disc and glyph colors in both states — it's the bar that
    /// changes, which is what makes the disc disappear into it.
    private var lennyMark: some View {
        Image("lenny")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundColor(.homeBackground)
            .frame(width: buttonSize, height: buttonSize)
            .background(Color.homeText, in: Circle())
            // One full turn as it slides across — the "roll".
            .rotationEffect(.degrees(focused ? 360 : 0))
            .accessibilityHidden(true)
    }
}

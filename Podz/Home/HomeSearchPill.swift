import SwiftUI

/// "Search a region or ask Lenny" — a pill field with Lenny's round button.
/// Typing filters the cards below; the button opens Lenny's itinerary
/// search. Focusing the field (Paper "Home2" frames) inverts the pill and
/// rolls Lenny from the trailing end to the leading end, where it stays
/// next to the text being typed.
struct HomeSearchPill: View {
    @Binding var text: String
    var onLenny: () -> Void

    @FocusState private var isFocused: Bool

    private let buttonSize: CGFloat = 40
    private let inset: CGFloat = 9

    var body: some View {
        ZStack(alignment: isFocused ? .leading : .trailing) {
            field
            lennyButton
                .padding(inset)
        }
        .frame(height: 60)
        .background(isFocused ? Color.homeText : Color.homePill, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
        .animation(.smooth(duration: 0.4), value: isFocused)
    }

    private var field: some View {
        TextField(
            "",
            text: $text,
            prompt: Text("Search a region or ask Lenny")
                .foregroundColor(isFocused ? .homeSubtitleOnInverse : .homeSubtitle)
        )
        .font(AppFont.regularLabel(14))
        .foregroundColor(isFocused ? .homeBackground : .homeText)
        // The caret follows the tint: against the inverted bar it has to
        // be the ground color.
        .tint(.homeBackground)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .focused($isFocused)
        // Room for the button on whichever side it's on, plus the gap.
        .padding(.leading, isFocused ? inset + buttonSize + 20 : 28)
        .padding(.trailing, isFocused ? 28 : inset + buttonSize + 8)
    }

    private var lennyButton: some View {
        Button(action: onLenny) {
            Image("lenny")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(isFocused ? .homeText : .homeBackground)
                .frame(width: buttonSize, height: buttonSize)
                .background(isFocused ? Color.homeBackground : Color.homeText, in: Circle())
                // One full turn as it slides across — the "roll".
                .rotationEffect(.degrees(isFocused ? 360 : 0))
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel("Ask Lenny")
    }
}

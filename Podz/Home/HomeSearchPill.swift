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
    /// Called on the keyboard's Search key.
    var onSubmit: () -> Void = {}

    private let buttonSize: CGFloat = 40
    private let inset: CGFloat = 9
    /// Lenny's button with its label ("Ask Lenny"): wide at rest, back to the
    /// round mark once Lenny mode rolls it to the other end.
    private let askWidth: CGFloat = 118

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped now and then while the pill is idle: Lenny's mark gives a little
    /// wave, a nudge that it can be asked.
    @State private var wave = 0

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
        .task {
            // A wave every few seconds while there's nothing typed or focused.
            while !Task.isCancelled && !reduceMotion {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !isLennyMode && !isFocused.wrappedValue { wave += 1 }
            }
        }
    }

    private var field: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(isLennyMode ? "Chamonix to Zermatt in 5 days" : "Search a region")
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
        .padding(.trailing, isLennyMode ? 28 : inset + askWidth + 8)
    }

    /// Lenny's button. At rest it says what it is, "Ask Lenny", on a solid
    /// capsule that stands out from the grey bar, and waves now and then. In
    /// Lenny mode it is the round mark again, rolled to the leading end and
    /// melted into the bar so only the eyes and the mouth stay visible.
    private var lennyMark: some View {
        Button {
            isLennyMode.toggle()
            isFocused.wrappedValue = true
        } label: {
            HStack(spacing: 7) {
                Image("lenny")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    // One full turn as it slides across: the "roll".
                    .rotationEffect(.degrees(isLennyMode ? 360 : 0))
                    .keyframeAnimator(initialValue: 0.0, trigger: wave) { view, angle in
                        view.rotationEffect(.degrees(angle))
                    } keyframes: { _ in
                        CubicKeyframe(-14, duration: 0.14)
                        CubicKeyframe(12, duration: 0.16)
                        CubicKeyframe(-8, duration: 0.14)
                        CubicKeyframe(0, duration: 0.16)
                    }

                if !isLennyMode {
                    Text("Ask Lenny")
                        .font(AppFont.semiBoldLabel(13))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .foregroundColor(.homeBackground)
            .frame(width: isLennyMode ? buttonSize : askWidth, height: buttonSize)
            .background(Color.homeText, in: Capsule())
            .clipped()
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel("Ask Lenny")
        .accessibilityHint("Describe your trip and Lenny finds the pods")
        .accessibilityAddTraits(isLennyMode ? .isSelected : [])
    }
}

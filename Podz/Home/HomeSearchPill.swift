import SwiftUI

/// "Search a region or ask Lenny" — a pill field with Lenny's round button
/// at its trailing edge. Typing filters the cards below; the button opens
/// Lenny's itinerary search.
struct HomeSearchPill: View {
    @Binding var text: String
    var onLenny: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: $text,
                prompt: Text("Search a region or ask Lenny").foregroundColor(.homeSubtitle)
            )
            .font(AppFont.regularLabel(14))
            .foregroundColor(.homeText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($isFocused)

            Button(action: onLenny) {
                Image("lenny")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.homeBackground)
                    .frame(width: 40, height: 40)
                    .background(Color.homeText, in: Circle())
            }
            .buttonStyle(TapScaleButtonStyle())
            .accessibilityLabel("Ask Lenny")
        }
        .padding(.leading, 28)
        .padding(.trailing, 9)
        .frame(height: 60)
        .background(Color.homePill, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
    }
}

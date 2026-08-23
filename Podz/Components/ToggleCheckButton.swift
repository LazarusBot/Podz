import SwiftUI

/// Circular toggle used for boolean filters like "Wifi" / "Pets"
/// (node 3665:1057 / 3665:1063 — "Check button").
/// Unchecked = plain pill circle. Checked = filled black with a checkmark.
struct ToggleCheckButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(isOn ? Color.appAccentBlack : Color.white)
                    .frame(width: 25, height: 25)
                    .overlay(
                        Circle().strokeBorder(Color.appBorder, lineWidth: 0.5)
                    )

                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct ToggleCheckButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            ToggleCheckButton(isOn: .constant(true))
            ToggleCheckButton(isOn: .constant(false))
        }
        .padding()
    }
}

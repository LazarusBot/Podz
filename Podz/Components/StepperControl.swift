import SwiftUI

/// The "− value +" stepper used for the "Hikers" filter row (node 3665:1030).
struct StepperControl: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...20
    /// True (default, every existing call site — Home's "Hikers" filter)
    /// keeps the pill background behind the number. ReservationSheet's
    /// guest stepper wants just the bare number between the +/- circles,
    /// no background of its own.
    var showsValueBackground: Bool = true
    /// What the value counts (e.g. "hikers", "guests") — folded into the
    /// +/- buttons' VoiceOver labels ("Decrease hikers") since the bare
    /// glyphs alone don't say what they're stepping.
    var label: String = "value"

    var body: some View {
        HStack(spacing: 10) {
            stepButton(systemImage: "minus", accessibilityLabel: "Decrease \(label)") {
                if value > range.lowerBound { value -= 1 }
            }

            valueLabel

            stepButton(systemImage: "plus", accessibilityLabel: "Increase \(label)") {
                if value < range.upperBound { value += 1 }
            }
        }
    }

    @ViewBuilder
    private var valueLabel: some View {
        let text = Text("\(value)")
            .font(AppFont.stepperValue())
            .foregroundColor(.appTextPrimary)
            .frame(minWidth: 31, minHeight: 31)

        if showsValueBackground {
            text.pillStyle()
        } else {
            text
        }
    }

    private func stepButton(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.appTextPrimary)
                .frame(width: 25, height: 25)
        }
        .pillStyle()
        .accessibilityLabel(accessibilityLabel)
    }
}

struct StepperControl_Previews: PreviewProvider {
    static var previews: some View {
        StepperControl(value: .constant(3))
            .padding()
            .background(Color.appBackground)
    }
}

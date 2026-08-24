import SwiftUI

/// Shared "pill" chrome: rounded-full shape, hairline border, soft drop
/// shadow, and a faint inset highlight along the top — matches every
/// button/chip in the Figma file (Chip, Stepper, CheckButton, Save...).
struct PillBackground: ViewModifier {
    var fill: Color = .white
    var borderColor: Color = .appBorder

    func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(fill)
                    .overlay(
                        Capsule()
                            .strokeBorder(borderColor, lineWidth: 0.5)
                    )
                    .overlay(
                        // faint top inset highlight, approximates the
                        // "inset 2px 7px 4px rgba(255,255,255,0.25)" from Figma
                        Capsule()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            .blur(radius: 1)
                            .offset(y: -1)
                            .mask(Capsule())
                    )
                    // The hairline border alone all but disappears against
                    // the near-white app background (#E1 border on #FB
                    // background) — this shadow is what actually keeps a
                    // pill's edge legible.
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            )
    }
}

extension View {
    func pillStyle(fill: Color = .white, border: Color = .appBorder) -> some View {
        modifier(PillBackground(fill: fill, borderColor: border))
    }
}

import SwiftUI

/// Shared "pill" chrome: rounded-full shape, hairline border, soft drop
/// shadow, and a faint inset highlight along the top — matches every
/// button/chip in the Figma file (Chip, Stepper, CheckButton, Save...).
struct PillBackground: ViewModifier {
    var fill: AnyShapeStyle = AnyShapeStyle(Color.white)
    var borderColor: Color = .appBorder
    var shadowColor: Color = .black.opacity(0.08)
    /// `nil` keeps the usual full `Capsule()`. Set this when the content
    /// can grow much taller than a normal single-line pill (e.g.
    /// ConversationView's composer once its reply banner is showing) —
    /// same fix HomeSearchRow uses for its own expanding search pill: a
    /// plain `Capsule()` chases height/2, so it balloons into an
    /// exaggerated stadium shape once the content gets tall, instead of
    /// reading as the same rounded-rectangle container just grown taller.
    var cornerRadius: CGFloat? = nil

    private var shape: AnyShape {
        if let cornerRadius {
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            AnyShape(Capsule())
        }
    }

    func body(content: Content) -> some View {
        content
            .background(
                shape
                    .fill(fill)
                    .overlay(shape.stroke(borderColor, lineWidth: 0.5))
                    .overlay(
                        // faint top inset highlight, approximates the
                        // "inset 2px 7px 4px rgba(255,255,255,0.25)" from Figma
                        shape
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            .blur(radius: 1)
                            .offset(y: -1)
                            .mask(shape)
                    )
                    // The hairline border alone all but disappears against
                    // the near-white app background (#E1 border on #FB
                    // background) — this shadow is what actually keeps a
                    // pill's edge legible.
                    .shadow(color: shadowColor, radius: 3, y: 1)
            )
    }
}

extension View {
    /// `fill` accepts any `ShapeStyle` — a plain `Color` (the common
    /// case, inferred automatically) or a `LinearGradient` (the Lenny
    /// chip's white-to-blue gradient) — wrapped in `AnyShapeStyle` so
    /// `PillBackground` can hold either without being generic itself.
    func pillStyle<S: ShapeStyle>(fill: S = Color.white, border: Color = .appBorder, shadow: Color = .black.opacity(0.08), cornerRadius: CGFloat? = nil) -> some View {
        modifier(PillBackground(fill: AnyShapeStyle(fill), borderColor: border, shadowColor: shadow, cornerRadius: cornerRadius))
    }
}

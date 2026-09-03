import SwiftUI

/// Replaces the system default press-dim (opacity toward black on any
/// plain `Button` with custom content) with a small scale-down and a
/// light haptic tick instead. `configuration.isPressed` is what any
/// `Button`'s style already tracks, no manual gesture needed (unlike
/// LikesFolderCard's own press handling, which needs a raw `DragGesture`
/// because it also drives a separate long-press/wiggle state most
/// buttons don't have).
///
/// Originally local to `ProfilePromoCard` (its own tap was flashing a
/// dark layer on press); pulled out here once the same fix was wanted on
/// every button inside every sheet in the app.
struct TapScaleButtonStyle: ButtonStyle {
    /// One shared, pre-warmed generator, not a fresh
    /// `UIImpactFeedbackGenerator(style: .light)` per tap — the Taptic
    /// Engine stays "cold" until `.prepare()` has run, and skipping it
    /// added a real, noticeable delay before every single tap's feedback
    /// (and the tap itself, since the button visually waits on the same
    /// gesture) actually landed — which is exactly what read as buttons
    /// being hard/unresponsive to tap. Re-prepared after every impact so
    /// the *next* tap is instant too, not just the first one.
    private static let generator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        return generator
    }()

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: AppMotion.snappy), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    Self.generator.impactOccurred()
                    Self.generator.prepare()
                }
            }
    }
}

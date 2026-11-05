import SwiftUI

/// The sheet close button (`design.md`, Buttons: Close): the flat round pill,
/// same fill, border and thin glyph as the back and like buttons.
struct CloseButton: View {
    /// Diameter of the pill.
    var size: CGFloat = 44
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CloseCross()
                .stroke(Color.homeText.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 12, height: 12)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.homePill.opacity(0.95))
                        .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 1))
                )
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel("Close")
    }
}

/// The "x" glyph, drawn like the back chevron: thin, round-capped strokes.
private struct CloseCross: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

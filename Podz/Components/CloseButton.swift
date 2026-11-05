import SwiftUI

/// The sheet close button (`design.md`, Buttons: Close): the flat round pill,
/// same fill, border and thin glyph as the back and like buttons.
struct CloseButton: View {
    /// Diameter of the pill.
    var size: CGFloat = 44
    var action: () -> Void

    /// In a control stack (83 round, beside the back pill) the "x" is drawn like
    /// the back chevron: 9 tall, at 35%. In a sheet's 44 it stays 12 at 45%.
    private var inStack: Bool { size > 60 }
    private var glyph: CGFloat { inStack ? 9 : 12 }

    var body: some View {
        Button(action: action) {
            CloseCross()
                .stroke(Color.homeText.opacity(inStack ? 0.35 : 0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: glyph, height: glyph)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.homePill.opacity(0.95))
                        .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 1))
                )
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel(tr("Close"))
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

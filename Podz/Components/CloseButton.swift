import SwiftUI

/// The "X in a light gray circle" dismiss button, repeated verbatim
/// across every sheet header in the app (AddFriendSheet, ShareFolderSheet,
/// ReservationSheet, PostsActivityView, LikeFolderPickerSheet,
/// LegalDocumentView) — one shared definition instead of six copies that
/// could silently drift apart from each other.
struct CloseButton: View {
    enum Style {
        /// The original light-gray circle with a bold glyph.
        case classic
        /// The flat pill from `design.md` — same fill, border and thin
        /// glyph as the back and like buttons.
        case pill
    }

    var style: Style = .classic
    /// Diameter of the circle; the classic glyph scales with it. 31 is the
    /// original size every sheet header used.
    var size: CGFloat = 31
    var action: () -> Void

    var body: some View {
        switch style {
        case .classic:
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: size * 14 / 31, weight: .semibold))
                    .foregroundColor(.appTextMuted)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.appIconButtonBackground))
            }
            .accessibilityLabel("Close")
        case .pill:
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

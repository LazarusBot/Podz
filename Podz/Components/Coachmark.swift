import SwiftUI

/// Dims and softly blurs the whole screen uniformly while a coachmark is
/// up, so a floating clone of the real control + its speech bubble read
/// as the one thing in focus without a literal cutout to keep pixel-
/// aligned against controls that don't have a plain rectangular shape
/// (Liquid Glass, in particular, adds its own shimmer/highlight bleed
/// past a view's literal frame). Both layers are deliberately light —
/// .ultraThinMaterial is already the softest blur Material offers, and
/// scaling it down further via .opacity keeps this a gentle focus cue
/// rather than a heavy-handed dimming. Originally local to HomeView's own
/// Lenny coachmark; pulled out here once `BottomTabBar`'s Profile-tab
/// coachmark wanted the identical treatment.
struct CoachmarkSpotlightScrim: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.14)
            Rectangle().fill(.ultraThinMaterial).opacity(0.5)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .transition(.opacity)
    }
}

/// First-time tip bubble pointing at some control — a single custom
/// outline (`CoachmarkBubbleShape`) rather than a rounded rect plus a
/// separate triangle glued underneath it, so fill and stroke both trace
/// the tail and body as one continuous edge with no seam where a two-
/// shape version would show a visible stroke line across the tail's
/// base. Same visual language everywhere it's used (HomeView's Lenny
/// chip, `BottomTabBar`'s Profile tab): dark pill background, white
/// text, a plain info glyph — explaining what a control is, not
/// illustrating the feature itself.
struct CoachmarkBubble: View {
    let message: String
    /// Tail center's distance from the bubble's own leading edge — the
    /// bubble itself is left-aligned to whatever it's pointing at (the
    /// call site positions it via `.offset`), but the tail is passed the
    /// target's own width so it can point at the target's actual
    /// midpoint instead of just wherever happens to land near the
    /// bubble's leading edge.
    var tailCenterOffset: CGFloat
    /// `true` when the bubble sits *above* what it's pointing at — flips
    /// the tail to the bottom edge instead of the top.
    var pointsDown: Bool = false
    var onDismiss: () -> Void

    private let tailWidth: CGFloat = 16
    private let tailHeight: CGFloat = 9
    private let cornerRadius: CGFloat = 16

    private var shape: CoachmarkBubbleShape {
        CoachmarkBubbleShape(cornerRadius: cornerRadius, tailWidth: tailWidth, tailHeight: tailHeight, tailInset: tailCenterOffset, pointsDown: pointsDown)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            // mediumLabel (Inter), not pillLabelMedium (Darker Grotesque)
            // — Darker Grotesque is the display face used for big chip
            // labels/numbers and reads thin at paragraph size even at its
            // own Medium weight; Inter Medium carries more visual weight
            // here, same reasoning as the original Lenny coachmark.
            Text(message)
                .font(AppFont.mediumLabel(15))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.top, pointsDown ? 14 : tailHeight + 14)
        .padding(.bottom, pointsDown ? tailHeight + 14 : 14)
        .background(shape.fill(Color.appAccentBlack))
        .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: pointsDown ? .bottomLeading : .topLeading)))
    }
}

/// Rounded rect with a speech-bubble tail on one edge, traced as one
/// outline via tangent-based corners (`addArc(tangent1End:tangent2End:)`)
/// rather than angle-based arcs — direction-agnostic, so there's no risk
/// of the usual clockwise/flipped-Y sign mistakes that angle math invites.
struct CoachmarkBubbleShape: Shape {
    var cornerRadius: CGFloat
    var tailWidth: CGFloat
    var tailHeight: CGFloat
    var tailInset: CGFloat
    /// `false` (default): tail on top, body below — pointing up at a
    /// target above the bubble. `true`: tail on bottom, body above —
    /// pointing down at a target below the bubble (`BottomTabBar`'s own
    /// floating tab bar sits low enough on screen that a bubble above it
    /// needs to point down, not up).
    var pointsDown: Bool = false

    func path(in rect: CGRect) -> Path {
        let body = pointsDown
            ? CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
            : CGRect(x: rect.minX, y: rect.minY + tailHeight, width: rect.width, height: rect.height - tailHeight)
        let r = min(cornerRadius, body.width / 2, body.height / 2)
        let tailCenterX = min(max(rect.minX + tailInset, body.minX + r + tailWidth / 2), body.maxX - r - tailWidth / 2)

        var path = Path()
        if pointsDown {
            path.move(to: CGPoint(x: body.minX + r, y: body.minY))
            path.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
            path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + r), radius: r)
            path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
            path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - r, y: body.maxY), radius: r)
            path.addLine(to: CGPoint(x: tailCenterX + tailWidth / 2, y: body.maxY))
            path.addLine(to: CGPoint(x: tailCenterX, y: rect.maxY))
            path.addLine(to: CGPoint(x: tailCenterX - tailWidth / 2, y: body.maxY))
            path.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
            path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - r), radius: r)
            path.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
            path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + r, y: body.minY), radius: r)
        } else {
            path.move(to: CGPoint(x: body.minX + r, y: body.minY))
            path.addLine(to: CGPoint(x: tailCenterX - tailWidth / 2, y: body.minY))
            path.addLine(to: CGPoint(x: tailCenterX, y: rect.minY))
            path.addLine(to: CGPoint(x: tailCenterX + tailWidth / 2, y: body.minY))
            path.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
            path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + r), radius: r)
            path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
            path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - r, y: body.maxY), radius: r)
            path.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
            path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - r), radius: r)
            path.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
            path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + r, y: body.minY), radius: r)
        }
        path.closeSubpath()
        return path
    }
}

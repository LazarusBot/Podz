import SwiftUI

/// "Lenny's pick": Lenny's disc with a small verified seal (a scalloped
/// badge with a check) tucked against its lower right, the way the Figma
/// lockup draws it. The seal is half the disc, centered half a disc to the
/// right and a bit below the disc's center, with a ring of the ground around
/// it so it reads as sitting on top. `homeText` disc and seal, `homeBackground`
/// eyes, ring and check, so it follows light and dark. The layout box is the
/// disc plus the part of the seal that hangs out.
struct LennyPickBadge: View {
    var size: CGFloat = 20

    private var seal: CGFloat { size * 0.5 }

    var body: some View {
        Image("lenny")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundColor(.homeBackground)
            .frame(width: size, height: size)
            .background(Color.homeText, in: Circle())
            .overlay {
                LennySeal()
                    .frame(width: seal, height: seal)
                    .offset(x: size * 0.5, y: size * 0.38)
            }
            // Room for the seal where it leaves the disc.
            .padding(.trailing, size * 0.25)
            .padding(.bottom, size * 0.13)
            .accessibilityHidden(true)
    }
}

/// The verified seal: a scalloped badge in `homeText`, a check in
/// `homeBackground`, and a ring of the ground around it.
struct LennySeal: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ScallopShape()
                    .fill(Color.homeBackground)
                    .frame(width: side * 1.24, height: side * 1.24)
                ScallopShape()
                    .fill(Color.homeText)
                    .frame(width: side, height: side)
                CheckShape()
                    .stroke(
                        Color.homeBackground,
                        style: StrokeStyle(lineWidth: max(side * 0.09, 1), lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: side, height: side)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// A rounded eight-lobed badge.
private struct ScallopShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        let steps = 160
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            let r = radius * (0.92 + 0.08 * cos(8 * angle))
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.34, y: rect.height * 0.50))
        path.addLine(to: CGPoint(x: rect.width * 0.46, y: rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.width * 0.68, y: rect.height * 0.38))
        return path
    }
}

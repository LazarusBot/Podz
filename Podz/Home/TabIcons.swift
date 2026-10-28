import SwiftUI

/// The three tab icons, ported from the Paper Home frame's 24x24 SVGs so
/// the line weight and curves match the design exactly. Each one scales to
/// whatever square it's given.
private func scaled(_ rect: CGRect) -> CGAffineTransform {
    let side = min(rect.width, rect.height) / 24
    return CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: side, y: side)
}

struct HomeIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 3, y: 10.5))
        p.addLine(to: CGPoint(x: 12, y: 3))
        p.addLine(to: CGPoint(x: 21, y: 10.5))
        p.addLine(to: CGPoint(x: 21, y: 20))
        p.addArc(tangent1End: CGPoint(x: 21, y: 21), tangent2End: CGPoint(x: 20, y: 21), radius: 1)
        p.addLine(to: CGPoint(x: 15, y: 21))
        p.addLine(to: CGPoint(x: 15, y: 15))
        p.addLine(to: CGPoint(x: 9, y: 15))
        p.addLine(to: CGPoint(x: 9, y: 21))
        p.addLine(to: CGPoint(x: 4, y: 21))
        p.addArc(tangent1End: CGPoint(x: 3, y: 21), tangent2End: CGPoint(x: 3, y: 20), radius: 1)
        p.closeSubpath()
        return p.applying(scaled(rect))
    }
}

struct HeartIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 12, y: 20))
        p.addCurve(to: CGPoint(x: 3, y: 10.8), control1: CGPoint(x: 12, y: 20), control2: CGPoint(x: 5, y: 15.6))
        p.addCurve(to: CGPoint(x: 7, y: 4.5), control1: CGPoint(x: 1.8, y: 7.6), control2: CGPoint(x: 3.9, y: 4.5))
        p.addCurve(to: CGPoint(x: 12, y: 7.5), control1: CGPoint(x: 9, y: 4.5), control2: CGPoint(x: 10.4, y: 5.6))
        p.addCurve(to: CGPoint(x: 17, y: 4.5), control1: CGPoint(x: 13.6, y: 5.6), control2: CGPoint(x: 15, y: 4.5))
        p.addCurve(to: CGPoint(x: 21, y: 10.8), control1: CGPoint(x: 20.1, y: 4.5), control2: CGPoint(x: 22.2, y: 7.6))
        p.addCurve(to: CGPoint(x: 12, y: 20), control1: CGPoint(x: 19, y: 15.6), control2: CGPoint(x: 12, y: 20))
        p.closeSubpath()
        return p.applying(scaled(rect))
    }
}

struct ProfileIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: 8, y: 4, width: 8, height: 8))
        p.move(to: CGPoint(x: 4, y: 21))
        p.addCurve(to: CGPoint(x: 12, y: 15), control1: CGPoint(x: 4, y: 17), control2: CGPoint(x: 7.6, y: 15))
        p.addCurve(to: CGPoint(x: 20, y: 21), control1: CGPoint(x: 16.4, y: 15), control2: CGPoint(x: 20, y: 17))
        return p.applying(scaled(rect))
    }
}

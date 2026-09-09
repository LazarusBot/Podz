//
//  TripPassTicketComponents.swift
//  Podz
//
//  Created by Max Prx on 07/09/2026.
//

import SwiftUI
import UIKit
import PassKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Wraps `PKAddPassButton` — Apple's own pill-shaped "Add to Apple
/// Wallet" control. No SwiftUI-native equivalent exists, hence the
/// `UIViewRepresentable` bridge; every real Wallet integration is
/// expected to use this exact button, not a custom lookalike.
struct AddToWalletButton: UIViewRepresentable {
    var action: () -> Void

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}

    /// Accepts whatever width SwiftUI proposes (full-width, via the call
    /// site's own `.frame(maxWidth: .infinity)`) instead of falling back
    /// to the button's own intrinsic width — `PKAddPassButton`'s pill
    /// background is a resizable image, so it stretches cleanly rather
    /// than distorting.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PKAddPassButton, context: Context) -> CGSize? {
        CGSize(
            width: proposal.width ?? uiView.intrinsicContentSize.width,
            height: uiView.intrinsicContentSize.height
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

/// Generated entirely on-device from `payload` via CoreImage's Code 128
/// generator — no network round trip, so this renders identically
/// whether there's signal or not. Not meant to be scanned by a live
/// validation system (see `TripPass.barcodePayload`'s own doc comment) —
/// just a fast way to compare against the printed confirmation code
/// beneath it.
struct BarcodeView: View {
    let payload: String

    var body: some View {
        if let uiImage = Self.generate(payload) {
            Image(uiImage: uiImage)
                // Nearest-neighbor, not the default smoothing — a
                // barcode's bars need crisp edges, and smoothing here
                // would just blur them into an unreadable gray.
                .interpolation(.none)
                .resizable()
        } else {
            RoundedRectangle(cornerRadius: AppRadius.r8)
                .fill(Color.gray.opacity(0.15))
                .overlay(Image(systemName: "barcode").foregroundColor(.appTextMuted))
        }
    }

    private static func generate(_ string: String) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)
        filter.quietSpace = 6
        filter.barcodeHeight = 80
        guard let outputImage = filter.outputImage else { return nil }
        // The raw output renders each bar only a pixel or two wide —
        // stretching it horizontally before rasterizing (not the final
        // UIImage) is what keeps every bar a crisp edge instead of a
        // blurry one once scaled up to the card's own size.
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 2.6, y: 1))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// The info half of the ticket — two half-circle notches punched out of
/// its own bottom edge. `TicketBottomShape` punches the matching two
/// half-circles out of its top edge; stacked with zero spacing, each
/// pair of halves lines up into one full circular notch, the way a real
/// perforated ticket is printed and torn. Corner rounding lives on the
/// call site's own `UnevenRoundedRectangle` clip, not here — this shape
/// only owns the punch.
///
/// The punch itself is a plain circle appended as its own subpath and
/// filled even-odd, not a hand-traced arc — a circle centered exactly on
/// the edge, filled even-odd against the card's own rectangle, is a pure
/// set-overlap: there's no clockwise/flipped-Y direction to get wrong,
/// unlike angle-based `addArc` (see `CoachmarkBubbleShape`'s own doc
/// comment for that exact failure mode elsewhere in this app).
struct TicketTopShape: Shape {
    var notchRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(Path(ellipseIn: CGRect(x: rect.minX - notchRadius, y: rect.maxY - notchRadius, width: notchRadius * 2, height: notchRadius * 2)))
        path.addPath(Path(ellipseIn: CGRect(x: rect.maxX - notchRadius, y: rect.maxY - notchRadius, width: notchRadius * 2, height: notchRadius * 2)))
        return path
    }
}

/// The stub half — notches punched from its own top edge. See
/// `TicketTopShape`'s own doc comment for the full reasoning; this is
/// its mirror image.
struct TicketBottomShape: Shape {
    var notchRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(Path(ellipseIn: CGRect(x: rect.minX - notchRadius, y: rect.minY - notchRadius, width: notchRadius * 2, height: notchRadius * 2)))
        path.addPath(Path(ellipseIn: CGRect(x: rect.maxX - notchRadius, y: rect.minY - notchRadius, width: notchRadius * 2, height: notchRadius * 2)))
        return path
    }
}

/// A single horizontal line spanning its own frame — stroked with a
/// dashed `StrokeStyle` at each call site, either as the tear line
/// between the ticket's two halves or as the route connector between
/// check-in and check-out.
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

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

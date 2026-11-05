//
//  BarcodeView.swift
//  Podz
//
//  Created by Max Prx on 07/09/2026.
//

import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

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
                .fill(Color.homePill)
                .overlay(Image(systemName: "barcode").foregroundColor(.homeSubtitle))
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

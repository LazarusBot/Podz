//
//  AddToWalletButton.swift
//  Podz
//
//  Created by Max Prx on 07/09/2026.
//

import SwiftUI
import UIKit
import PassKit

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

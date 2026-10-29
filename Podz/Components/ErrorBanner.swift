import SwiftUI

/// Error display — a red-tinted card instead of plain floating red text,
/// so it reads as a distinct, designed piece of UI rather than blending
/// into the surface behind it.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.r12)
                .fill(Color.red.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.r12)
                        .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

import SwiftUI

/// A single skeleton placeholder — a soft gray rounded shape with a light
/// band sweeping across it. Caller sizes it via `.frame(...)`. Shared by
/// the launch skeleton (OnboardingView) and any in-app loading state that
/// wants the same "content shape" placeholder instead of a plain spinner.
struct SkeletonShape: View {
    var cornerRadius: CGFloat
    @State private var sweep = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black.opacity(0.06))
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.8), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width)
                    .offset(x: sweep ? geo.size.width : -geo.size.width)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    sweep = true
                }
            }
    }
}

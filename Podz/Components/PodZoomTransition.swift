import SwiftUI

extension View {
    /// Marks a pod card's photo as the source of the zoom transition into
    /// `PodDetailView` (paired with `.navigationTransition(.zoom)` on the
    /// `fullScreenCover` that presents it). The clip shape has to match the
    /// photo's own rounding so the zoom starts from the real rounded rect
    /// instead of a square that snaps rounded. A `nil` namespace is a
    /// no-op, for cards that can be shown somewhere with no zoom wired up.
    @ViewBuilder
    func podZoomSource(
        id: UUID,
        in namespace: Namespace.ID?,
        cornerRadius: CGFloat,
        style: RoundedCornerStyle = .continuous
    ) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: style))
            }
        } else {
            self
        }
    }
}

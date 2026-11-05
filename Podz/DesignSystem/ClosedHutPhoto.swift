import SwiftUI

extension View {
    /// A closed hut's photo on Home: blurred and a little dimmed, with a white centered
    /// "Closed until June" (the tile stays tappable). Apply it to the tile
    /// before it is clipped.
    func closedHutLook(_ pod: Pod, textSize: CGFloat = 13) -> some View {
        let status = OpeningStatus.evaluate(pod.openingHours)
        let isClosed = status?.isOpen == false
        return blur(radius: isClosed ? 18 : 0, opaque: isClosed)
            .overlay {
                if isClosed, let status {
                    ZStack {
                        Color.photoScrim.opacity(0.25)
                        T(status.label)
                            .font(AppFont.semiBoldLabel(textSize))
                            .foregroundColor(.onPhoto)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

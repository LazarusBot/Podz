import SwiftUI

extension View {
    /// A closed hut's photo on Home: grey, dimmed, with a white centered
    /// "Closed until June" (the tile stays tappable). Apply it to the tile
    /// before it is clipped.
    func closedHutLook(_ pod: Pod, textSize: CGFloat = 13) -> some View {
        let status = OpeningStatus.evaluate(pod.openingHours)
        let isClosed = status?.isOpen == false
        return saturation(isClosed ? 0 : 1)
            .overlay {
                if isClosed, let status {
                    ZStack {
                        Color.photoScrim.opacity(0.45)
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

import SwiftUI

extension Pod {
    /// Whether its opening hours say it's closed right now (no hours, or hours
    /// that can't be trusted, never count as closed).
    var isClosedNow: Bool { OpeningStatus.evaluate(openingHours)?.isOpen == false }
}

extension View {
    /// A closed hut's photo on Home: grey, dimmed, with a white centered
    /// "Closed" (the tile stays tappable; the detail says until when).
    /// Apply it to the tile before it is clipped.
    func closedHutLook(_ isClosed: Bool, textSize: CGFloat = 15) -> some View {
        saturation(isClosed ? 0 : 1)
            .overlay {
                if isClosed {
                    ZStack {
                        Color.photoScrim.opacity(0.45)
                        T("Closed")
                            .font(AppFont.semiBoldLabel(textSize))
                            .foregroundColor(.onPhoto)
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

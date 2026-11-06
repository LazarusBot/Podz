import SwiftUI

/// Under a finished stay in Reservations: how it went, as the traveler told
/// Lenny, and the photos they kept with it (see them all on the hut's page).
struct StayFeedbackLine: View {
    let reservationId: UUID
    @ObservedObject private var store = StayFeedbackStore.shared

    var body: some View {
        if let feedback = store.entries[reservationId], let mood = feedback.mood {
            VStack(alignment: .leading, spacing: 8) {
                T(mood == .good ? "A good stay" : "Not a great stay")
                    .font(AppFont.regularLabel(12))
                    .foregroundColor(.homeSubtitle)
                let urls = store.photoURLs(for: reservationId)
                if !urls.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(urls.prefix(4)), id: \.self) { url in
                            StayPhotoImage(url: url, maxPixel: 120)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
    }
}

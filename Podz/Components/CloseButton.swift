import SwiftUI

/// The "X in a light gray circle" dismiss button, repeated verbatim
/// across every sheet header in the app (AddFriendSheet, ShareFolderSheet,
/// ReservationSheet, PostsActivityView, LikeFolderPickerSheet,
/// LegalDocumentView) — one shared definition instead of six copies that
/// could silently drift apart from each other.
struct CloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appTextMuted)
                .frame(width: 31, height: 31)
                .background(Circle().fill(Color.appIconButtonBackground))
        }
        .accessibilityLabel("Close")
    }
}

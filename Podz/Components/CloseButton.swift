import SwiftUI

/// The "X in a light gray circle" dismiss button, repeated verbatim
/// across every sheet header in the app (AddFriendSheet, ShareFolderSheet,
/// ReservationSheet, PostsActivityView, LikeFolderPickerSheet,
/// LegalDocumentView) — one shared definition instead of six copies that
/// could silently drift apart from each other.
struct CloseButton: View {
    /// Diameter of the circle; the glyph scales with it. 31 is the
    /// original size every sheet header used.
    var size: CGFloat = 31
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: size * 14 / 31, weight: .semibold))
                .foregroundColor(.appTextMuted)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.appIconButtonBackground))
        }
        .accessibilityLabel("Close")
    }
}

import SwiftUI

/// A round pill in the pod page's action row, same flat style as back and Book.
/// Unliked, a tap opens the folder picker (the frosted folders and the photo
/// dropping into one); liked, a tap removes the like.
struct PodLikeButton: View {
    let pod: Pod

    @ObservedObject private var likesStore = LikesStore.shared
    @State private var showFolderPicker = false

    private var isLiked: Bool { likesStore.isLiked(pod) }

    var body: some View {
        DetailRoundButton(
            accessibilityLabel: isLiked ? "Remove from likes" : "Add to likes",
            action: {
                if isLiked {
                    Task { await likesStore.removeLike(pod) }
                } else {
                    showFolderPicker = true
                }
            }
        ) {
            ZStack {
                if isLiked { HeartIconShape().fill(Color.homeText) }
                HeartIconShape()
                    .stroke(Color.homeText.opacity(isLiked ? 1 : 0.45), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 22, height: 22)
            .keyframeAnimator(initialValue: 1.0, trigger: isLiked) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.3, duration: 0.15)
                SpringKeyframe(1.0, spring: .bouncy)
            }
        }
        .likeFolderPicker(for: pod, isPresented: $showFolderPicker)
    }
}

import SwiftUI

/// One pod in a Likes folder: a tall photo tile with the name on a soft
/// scrim. The selected tile is at full strength with a check; the others
/// are dimmed (same tile as the onboarding's region picker).
struct FolderPodTile: View {
    let pod: Pod
    let photoURL: String?
    let isSelected: Bool
    /// Edit mode: the tile wiggles and a minus on its corner removes it.
    var isEditing = false
    var onTap: () -> Void
    var onRemove: () -> Void = {}
    var onLongPress: () -> Void = {}

    @State private var wiggle: Double = 0

    var body: some View {
        Button(action: onTap) {
            Color.clear
                .aspectRatio(166.0 / 216.0, contentMode: .fit)
                .overlay { PodPhoto(url: photoURL, coordinate: pod.coordinate) }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 90)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(pod.name)
                        .font(AppFont.semiBoldLabel(15))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.leading, 18)
                        .padding(.trailing, 12)
                        .padding(.bottom, 16)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        CheckGlyphShape()
                            .stroke(Color.black, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                            .frame(width: 12, height: 10)
                            .frame(width: 26, height: 26)
                            .background(Color.white, in: Circle())
                            .padding(14)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .opacity(isEditing || isSelected ? 1 : 0.55)
                .contentShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(isEditing ? wiggle : 0))
        .overlay(alignment: .topLeading) {
            if isEditing {
                Button(action: onRemove) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.red))
                        .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Remove from folder"))
                .padding(10)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onLongPress()
            }
        )
        .onChange(of: isEditing) { _, editing in
            if editing {
                withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true)) {
                    wiggle = Double.random(in: 0.7...1.1)
                }
            } else {
                withAnimation(.linear(duration: 0)) { wiggle = 0 }
            }
        }
        .accessibilityLabel(pod.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

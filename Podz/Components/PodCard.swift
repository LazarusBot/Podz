import SwiftUI

struct PodCard: View {
    let pod: Pod
    var photoURL: String? = nil
    var size: CGFloat = 160
    var showLikeButton: Bool = false
    var onTap: () -> Void = {}
    @ObservedObject private var likesStore = LikesStore.shared
    @State private var showFolderPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                PodPhoto(url: photoURL)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.75), lineWidth: 3)
                    )
                
                if showLikeButton {
                    Button {
                        if likesStore.isLiked(pod) {
                            Task { await likesStore.removeLike(pod) }
                        } else {
                            showFolderPicker = true
                        }
                    } label: {
                        Image(systemName: likesStore.isLiked(pod) ? "heart.fill" : "heart")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(likesStore.isLiked(pod) ? .red : .white)
                            .frame(width: 25, height: 25)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5))
                    }
                    .padding(6)
                    .likeFolderPicker(for: pod, isPresented: $showFolderPicker)
                }
            }
            
            Text(pod.name)
                .font(AppFont.pillLabel(12))
                .foregroundColor(.black)
                .lineLimit(1)
            
            Text(pod.region ?? pod.country)
                .font(AppFont.itemHelper(10))
                .foregroundColor(.black)
                .lineLimit(1)
            
            HStack(spacing: 5) {
                Circle().fill(Color.appAvailableGreen).frame(width: 6, height: 6)
                Text("\(pod.bedsTotal ?? 0) beds available")
                    .font(AppFont.itemHelper(10))
                    .foregroundColor(.appAvailableGreen)
            }
        }
        .frame(width: size, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        
    }
}

/// "Preferred pods - <Region>" section: title + horizontal scroll of cards
/// (node 3779:2081 / 3779:2114 pattern — repeat this per region).
struct PodSection: View {
    let title: String
    let pods: [Pod]
    var photoURLs: [UUID: String] = [:]
    var showLikeButtons: Bool = false
    var onTapPod: (Pod) -> Void = { _ in }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.pillLabel(14))
                .fontWeight(.black)
                .foregroundColor(.black)
                .padding(.leading, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(pods) { pod in
                        PodCard(pod: pod, photoURL: photoURLs[pod.id], showLikeButton: showLikeButtons, onTap: { onTapPod(pod) })
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 24)
            }
        }
        .padding(.vertical, 24)
    }
}

/// Shared photo loader: remote URL via AsyncImage, gray placeholder
/// otherwise. Same pattern as AvatarView.
struct PodPhoto: View {
    var url: String?
    
    var body: some View {
        CachedAsyncImage(url: url) { placeholder }
            .aspectRatio(contentMode: .fill)
    }
    
    private var placeholder: some View {
        Rectangle().fill(Color.gray.opacity(0.25))
            .overlay(Image(systemName: "photo").foregroundColor(.white))
    }
}

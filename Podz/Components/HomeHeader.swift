import SwiftUI

/// "Good morning, @bosoveille" + round avatar (node 3779:2057).
struct HomeHeader: View {
    let greeting: String
    let username: String
    var avatarImageName: String? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(AppFont.mediumLabel())
                    .foregroundColor(.appTextMuted)
                Text("@\(username)")
                    .font(AppFont.pillLabel(24))
                    .foregroundColor(.black)
            }
            Spacer()
            AvatarView(imageName: avatarImageName, size: 42)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color.appHomeBackground)
    }
}

/// Reusable round avatar with white ring + soft shadow, used in the
/// header, the bottom tab bar ("Profile"), and the pinned post card.
///
/// Accepts either a local asset name ("avatar-placeholder") or a remote
/// URL string (e.g. a Supabase Storage public URL from `profile.avatarURL`)
/// — figures out which one it got automatically.
struct AvatarView: View {
    var imageName: String?
    var size: CGFloat = 42
    
    var body: some View {
        Group {
            if let imageName, imageName.hasPrefix("http") {
                CachedAsyncImage(url: imageName) { placeholder }
                    .aspectRatio(contentMode: .fill)
            } else if let imageName, UIImage(named: imageName) != nil {
                Image(imageName).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    private var placeholder: some View {
        Circle().fill(Color.gray.opacity(0.3))
            .overlay(Image(systemName: "person.fill").foregroundColor(.white))
    }
}

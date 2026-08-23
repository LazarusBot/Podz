import SwiftUI

/// "Pinned by ..." post card at the bottom of the feed (node 3780:2367).
struct PinnedPostCard: View {
    let authorName: String
    let location: String
    let timeAgo: String
    let avatarImageName: String?
    let photoImageName: String

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                HStack(spacing: 10) {
                    AvatarView(imageName: avatarImageName, size: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pinned by \(authorName)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                        Text(location)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.appTextMuted)
                    }
                }
                Spacer()
                Text(timeAgo)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(red: 0x8E/255, green: 0x90/255, blue: 0x99/255))
                    .underline()
            }
            .padding(.horizontal, 20)

            Divider().background(Color.appBorder)

            Group {
                if UIImage(named: photoImageName) != nil {
                    Image(photoImageName).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color.gray.opacity(0.25))
                        .overlay(Image(systemName: "photo").foregroundColor(.white))
                }
            }
            .frame(height: 194)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.75), lineWidth: 3)
            )
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.appFieldBg)
                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Color.appBorder, lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 1, y: 3)
        )
        .padding(.horizontal, 24)
    }
}

#Preview {
    PinnedPostCard(
        authorName: "Dominic COBB",
        location: "Dolomiti, Italian Alps",
        timeAgo: "4 days ago",
        avatarImageName: nil,
        photoImageName: "pinned-photo"
    )
    .background(Color.appHomeBackground)
}

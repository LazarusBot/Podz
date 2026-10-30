import SwiftUI

/// Reusable flat avatar (no ring, no shadow — `design.md`), used in friend
/// and post rows, Profile and more — round by
/// default everywhere, since that's every existing call site.
///
/// Accepts either a local asset name ("avatar-placeholder") or a remote
/// URL string (e.g. a Supabase Storage public URL from `profile.avatarURL`)
/// — figures out which one it got automatically.
struct AvatarView: View {
    var imageName: String?
    var size: CGFloat = 42
    /// Nil (default) clips to a circle, matching every call site this
    /// had before this parameter existed. A value switches to a rounded
    /// square at that radius instead — e.g. ProfileView's own persistent
    /// top-bar avatar, matching PodDetailView's small top-bar photo
    /// (`RoundedRectangle(cornerRadius: AppRadius.r10, style: .continuous)`).
    var cornerRadius: CGFloat? = nil
    /// A thin white ring around the photo. Off by default: the design
    /// system is flat, a photo needs no outline.
    var showsStroke: Bool = false

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
        .modifier(AvatarClipStyle(cornerRadius: cornerRadius, showsStroke: showsStroke))
    }

    /// A plain `Rectangle`, not `Circle` — this fills the *entire* square
    /// frame regardless of which shape the outer clip ends up using;
    /// a `Circle` here would leave a rounded square's corners visibly
    /// uncovered instead of relying on the outer clip to crop correctly.
    private var placeholder: some View {
        Rectangle().fill(Color.gray.opacity(0.3))
            .overlay(Image(systemName: "person.fill").foregroundColor(.white))
    }
}

/// Circle vs. rounded-square clip + matching border, kept out of
/// `AvatarView.body` itself since `.strokeBorder` needs a concrete
/// `InsettableShape` type per branch — `AnyShape` doesn't conform to it,
/// so a type-erased single code path isn't an option here.
private struct AvatarClipStyle: ViewModifier {
    let cornerRadius: CGFloat?
    var showsStroke: Bool = true

    func body(content: Content) -> some View {
        if let cornerRadius {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    if showsStroke {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                    }
                }
        } else {
            content
                .clipShape(Circle())
                .overlay {
                    if showsStroke {
                        Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                    }
                }
        }
    }
}

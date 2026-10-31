import SwiftUI
import CoreLocation

/// The pieces the pod detail and the Likes folder view share, so the two
/// screens look and behave the same (Paper "DetailView" frames).
enum DetailLayout {
    /// The control stack (back pill + the page's action) sits this far above
    /// the home-indicator zone, i.e. `controlStackGap + 34` = 74 from the
    /// screen's physical bottom edge on a Face ID iPhone (the Paper frames).
    static let controlStackGap: CGFloat = 40

    /// Photo heights from the Paper frames, as a share of the screen.
    static let stackedPhotoShare: CGFloat = 524 / 852
    static let extendedPhotoShare: CGFloat = 250 / 852

    /// The pod detail's photo is a little shorter than the others, to leave room
    /// for the key facts under the name.
    static let podPhotoShare: CGFloat = 380 / 852

    static func podPhotoHeight(screenHeight: CGFloat) -> CGFloat { screenHeight * podPhotoShare }

    static func photoHeight(screenHeight: CGFloat, isExtended: Bool) -> CGFloat {
        screenHeight * (isExtended ? extendedPhotoShare : stackedPhotoShare)
    }
}

/// The fade into the ground that content scrolls under, behind the control
/// stack: clear over the top half, solid `homeBackground` at the bottom edge.
/// Used by the Likes folder view, the Likes tab and the save-to-folder sheet.
struct BottomFade: View {
    var body: some View {
        LinearGradient(
            stops: [.init(color: .clear, location: 0.5), .init(color: .homeBackground, location: 1)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// The swipeable photo on top: rounded only along the bottom, Lenny's badge
/// half over its bottom edge, the pager dots fanned above the badge. One
/// slot per page (`nil` draws the placeholder).
struct DetailPhotoPager: View {
    let slots: [String?]
    /// Optional — `.scrollPosition(id:)` needs it.
    @Binding var pageIndex: Int?
    let width: CGFloat
    let height: CGFloat
    /// The pod's spot: with no photo at all the picture is its satellite view.
    var coordinate: CLLocationCoordinate2D?
    /// The corners: rounded along the bottom only (the big photo), or all four
    /// when it has shrunk to a thumbnail. Animatable, so it can morph.
    var topRadius: CGFloat = 0
    var bottomRadius: CGFloat = 75
    /// The pager dots; hidden when the photo is a thumbnail.
    var showsBadge = true

    /// One empty slot when there is nothing yet, so the placeholder shows.
    private var pages: [String?] { slots.isEmpty ? [nil] : slots }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, url in
                    PodPhoto(url: url, coordinate: coordinate)
                        .frame(width: width, height: height)
                        .clipped()
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageIndex)
        .frame(width: width, height: height)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: topRadius, bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius, topTrailingRadius: topRadius, style: .continuous
        ))
        .overlay(alignment: .bottom) {
            PodPhotoDots(photoCount: slots.count, currentIndex: pageIndex ?? 0)
                .padding(.bottom, 24)
                .opacity(showsBadge ? 1 : 0)
        }
        .zIndex(1)
    }
}

/// The flat capsule every button on these screens sits on (`design.md`).
struct DetailPill: View {
    var body: some View {
        Capsule()
            .fill(Color.homePill.opacity(0.95))
            .overlay(Capsule().strokeBorder(Color.homeBackground, lineWidth: 1))
    }
}

/// 83 x 83 round pill with any glyph in it.
struct DetailRoundButton<Label: View>: View {
    let accessibilityLabel: String
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(width: 83, height: 83)
                .background(DetailPill())
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// The back pill: a thin "<" at 35%.
struct DetailBackButton: View {
    var action: () -> Void

    var body: some View {
        DetailRoundButton(accessibilityLabel: "Back", action: action) {
            DetailBackChevron()
                .stroke(Color.homeText.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 12)
        }
    }
}

/// The wide pill ("Book", "Open"): 14 regular label, fills the row. When
/// `isHighlighted` it inverts (`homeText` fill, `homeBackground` label): the
/// action that's now the one to take.
struct DetailTextButton: View {
    let title: String
    var isHighlighted = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.regularLabel(14))
                .foregroundColor(isHighlighted ? .homeBackground : .homeText)
                // A long label ("Book through the hut") takes two centered lines.
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 83)
                .background {
                    if isHighlighted {
                        Capsule().fill(Color.homeText)
                    } else {
                        DetailPill()
                    }
                }
        }
        .buttonStyle(TapScaleButtonStyle())
    }
}

/// "Name  -  detail": the name at 20, the detail beside it at 14.
func detailTitle(_ name: String, detail: String?) -> Text {
    let nameText = Text(name).font(AppFont.semiBoldLabel(20))
    guard let detail else { return nameText }
    let detailText = Text("  -  \(detail)").font(AppFont.semiBoldLabel(14))
    return Text("\(nameText)\(detailText)")
}

/// The back pill's "<" glyph from the Paper frames (8x12).
struct DetailBackChevron: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.125))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.1875, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.875))
        return path
    }
}

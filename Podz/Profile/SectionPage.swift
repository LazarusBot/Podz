import SwiftUI

/// The bottom inset of the device (the home-indicator zone), read from the
/// window. Pages inside a tab ignore the bottom safe area, so they can't ask
/// their own geometry for it.
enum ScreenInsets {
    static var bottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
    }
}

/// The page every screen Profile opens is built on (`design.md`): a big
/// title at the top, no navigation bar, and at the bottom the same pill row
/// as the pod detail: the round back pill, plus whatever action the page has
/// beside it. The content scrolls behind a fade into the ground.
struct SectionPage<Content: View, Trailing: View>: View {
    let title: String
    var onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    /// Room under the content so the last row clears the pill row.
    private static var bottomRoom: CGFloat { 190 }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(-0.6)
                        .foregroundColor(.homeText)
                        .padding(.horizontal, 24)
                        .padding(.top, 25)
                        .padding(.bottom, 16)

                    content()

                    Color.clear.frame(height: Self.bottomRoom)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            // Fade into the ground behind the pills.
            LinearGradient(
                colors: [Color.homeBackground.opacity(0), Color.homeBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            .allowsHitTesting(false)

            HStack(spacing: 13) {
                DetailBackButton(action: onBack)
                trailing()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40 + ScreenInsets.bottom)
        }
        .background(Color.homeBackground.ignoresSafeArea())
    }
}

extension SectionPage where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() }, content: content)
    }
}

/// A quiet label above a group of rows ("Requests", "Upcoming").
struct SectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppFont.regularLabel(13))
            .foregroundColor(.homeSubtitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

/// A plain hairline between rows, in the ink color at 8%.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Color.homeText.opacity(0.08)).frame(height: 0.5)
    }
}

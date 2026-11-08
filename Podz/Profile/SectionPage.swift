import SwiftUI

/// The bottom inset of the device (the home-indicator zone), read from the
/// window. Pages inside a tab ignore the bottom safe area, so they can't ask
/// their own geometry for it.
enum ScreenInsets {
    /// The width of the screen the app is on (through the scene, not the
    /// deprecated `UIScreen.main`).
    static var screenWidth: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }
            .first ?? 393
    }

    /// The height of the screen the app is on.
    static var screenHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }
            .first ?? 852
    }

    static var top: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 0
    }

    static var bottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
    }
}

extension View {
    /// Puts the bottom control stack 74 from the physical bottom edge. Only
    /// for a container that ignores the bottom safe area (a tab's content,
    /// or a screen that ignores all safe areas); inside a sheet the safe
    /// area is already respected, so use `DetailLayout.controlStackGap`
    /// alone there.
    func controlStackPadding() -> some View {
        padding(.bottom, DetailLayout.controlStackGap + ScreenInsets.bottom)
    }
}

/// Where a page's fade into the ground begins and where it is solid, as shares of
/// the screen's height (0 top, 1 bottom). The fade covers the whole screen, so
/// moving it is just changing these two numbers: a page with something floating
/// above the pills (Reservations' Lenny bubble) starts it higher.
struct SectionFade {
    var start: CGFloat
    var solid: CGFloat

    /// Rows melt away over the lower part and are gone behind the pills.
    static let standard = SectionFade(start: 0.77, solid: 0.93)
    /// Higher, for a floating bubble above the pills.
    static let tall = SectionFade(start: 0.62, solid: 0.78)
    /// Photo cards (See all): they must never be seen around the pill.
    static let photos = SectionFade(start: 0.71, solid: 0.91)
}

/// The fade into the ground over the whole screen, edge to edge, from where
/// `fade` starts to where it is solid. Any page whose rows scroll under the
/// pills uses this one (`SectionPage`, the Lenny plan and summary).
struct SectionFadeLayer: View {
    var fade: SectionFade = .standard

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.homeBackground.opacity(0), location: fade.start),
                .init(color: Color.homeBackground, location: fade.solid),
                .init(color: Color.homeBackground, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        // The whole screen, edge to edge: nothing shows below it.
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// The page every screen Profile opens is built on (`design.md`): a big
/// title at the top, no navigation bar, and at the bottom the same pill row
/// as the pod detail: the round back pill, plus whatever action the page has
/// beside it. The content scrolls behind a fade into the ground.
struct SectionPage<Content: View, Trailing: View>: View {
    let title: String
    var onBack: () -> Void
    /// The fade into the ground, over the whole screen (see `SectionFade`).
    var fade: SectionFade = .standard
    /// A page shown in a sheet or a cover respects the bottom safe area (a tab's
    /// content doesn't): the pills sit 40 above it. The fade covers the whole
    /// screen either way.
    var respectsSafeArea = false
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    /// Room under the content so the last row clears the pill row.
    private static var bottomRoom: CGFloat { 152 }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    T(title)
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
            SectionFadeLayer(fade: fade)

            HStack(spacing: 13) {
                DetailBackButton(action: onBack)
                trailing()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, respectsSafeArea ? DetailLayout.controlStackGap : DetailLayout.controlStackGap + ScreenInsets.bottom)
        }
        .background(Color.homeBackground.ignoresSafeArea())
    }
}

extension SectionPage where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void, fade: SectionFade = .standard, respectsSafeArea: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, onBack: onBack, fade: fade, respectsSafeArea: respectsSafeArea, trailing: { EmptyView() }, content: content)
    }
}

/// A quiet label above a group of rows ("Requests", "Upcoming").
struct SectionHeading: View {
    let title: String

    var body: some View {
        T(title)
            .font(AppFont.regularLabel(13))
            .foregroundColor(.homeSubtitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

/// A `SectionHeading` that opens and closes what's under it: the same quiet 13
/// `homeSubtitle` label, the number of rows beside it and a thin chevron that
/// turns down when it's open. For a group that shouldn't take the page (Past
/// reservations): closed, only this line shows. The caller shows the rows when
/// `isOpen`, inside `withAnimation`; the toggle here already is.
struct CollapsibleHeading: View {
    let title: String
    let count: Int
    @Binding var isOpen: Bool

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { isOpen.toggle() }
        } label: {
            HStack(spacing: 6) {
                T(title)
                T("\(count)")
                    .opacity(0.6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .padding(.leading, 2)
                Spacer(minLength: 0)
            }
            .font(AppFont.regularLabel(13))
            .foregroundColor(.homeSubtitle)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 6)
            // The whole line is the target, not just the words.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tr(title)), \(count)")
        .accessibilityValue(tr(isOpen ? "Expanded" : "Collapsed"))
        .accessibilityAddTraits(.isButton)
    }
}

/// A plain hairline between rows, in the ink color at 8%.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Color.homeText.opacity(0.08)).frame(height: 0.5)
    }
}

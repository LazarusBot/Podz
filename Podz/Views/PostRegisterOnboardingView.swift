import SwiftUI

/// The 4-step onboarding shown once, right after a successful register
/// (never after a plain login — see `AuthManager.justRegistered`).
/// Steps 1-3 share one fixed chrome layout (see `OnboardingCarousel`) —
/// only the photo underneath actually pages; only the last step has the
/// dark bottom gradient (matches Login/Register in Figma — the two
/// middle steps are a plain photo, no gradient). The splash step (0) has
/// its own background — a progressive blur with no gradient at all.
struct PostRegisterOnboardingView: View {
    var onFinished: () -> Void

    @State private var step = 0

    var body: some View {
        Group {
            if step == 0 {
                OnboardingSplashStep(onTap: { step = 1 })
            } else {
                OnboardingCarousel(step: $step, onFinished: onFinished)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step == 0)
    }
}

// MARK: - Step 0: splash / logo

private struct OnboardingSplashStep: View {
    var onTap: () -> Void

    var body: some View {
        VStack {
            Spacer()

            Group {
                if UIImage(named: "podz") != nil {
                    Image("podz").resizable().scaledToFit().frame(height: 60)
                } else {
                    Text("Podz")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            Text("Touch to start →")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .underline()
                .padding(.bottom, 45)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplashProgressiveBlurBackground())
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

/// The splash step's own background — unlike every other auth/onboarding
/// screen, this one has no dark gradient, and blurs progressively
/// starting at the vertical middle instead. Built as a sharp copy + a
/// blurred copy masked by a top-to-bottom gradient, since there's no
/// direct "progressive blur" modifier.
private struct SplashProgressiveBlurBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let uiImage = UIImage(named: "bg") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()

                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: 20)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.5),
                                    .init(color: .black, location: 1.0)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                } else {
                    LinearGradient.appAuthImageFallback
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Steps 1-3: fixed chrome, swipeable photo

/// The three content steps share one identical layout (logo, title/
/// subtitle, pagination dots, CTA) — only the photo, title, subtitle,
/// and button label actually change between them. So there's exactly
/// one instance of the chrome, positioned once and never rebuilt;
/// swiping only pages the photo underneath via a native TabView, and
/// the chrome's text/label crossfades to match instead of sliding.
private struct OnboardingCarousel: View {
    @Binding var step: Int
    var onFinished: () -> Void

    private struct Page {
        let title: String
        let subtitle: String
        let buttonTitle: String
        let imageName: String
        let showGradient: Bool
    }

    private let pages: [Page] = [
        Page(
            title: "Find your pod in the wild",
            subtitle: "Discover unique, architectural stays and cozy cabins hidden deep within nature's most stunning landscapes.",
            buttonTitle: "Continue",
            imageName: "Hutte1",
            showGradient: true
        ),
        Page(
            title: "Escape to off-grid seclusion",
            subtitle: "Unplug and recharge in architecturally stunning, eco-friendly spaces built to let you reconnect with the rhythms of the wild.",
            buttonTitle: "Continue",
            imageName: "Hutte2",
            showGradient: true
        ),
        Page(
            title: "Your adventure starts here",
            subtitle: "Step inside architecturally stunning eco-pods designed to blend seamlessly with nature. Book, unlock, and unplug with absolute ease.",
            buttonTitle: "Get started",
            imageName: "Hutte3",
            showGradient: true
        )
    ]

    private var index: Int { step - 1 }
    private var current: Page { pages[index] }

    var body: some View {
        ZStack {
            // Only this pages — native, GPU-driven, full-bleed.
            TabView(selection: $step) {
                ForEach(1...3, id: \.self) { pageStep in
                    OnboardingPhotoBackground(
                        imageName: pages[pageStep - 1].imageName,
                        showGradient: pages[pageStep - 1].showGradient
                    )
                    .tag(pageStep)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Fixed chrome — same position on every page.
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if UIImage(named: "podz") != nil {
                        Image("podz").resizable().scaledToFit().frame(height: 25)
                    } else {
                        Text("Podz")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 32)

                Spacer()

                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(current.title)
                            .font(AppFont.pillLabelBold(40))
                            .tracking(-1)
                            .foregroundColor(.white)
                            .lineSpacing(4)
                            .contentTransition(.opacity)
                        Text(current.subtitle)
                            .font(.system(size: 16))
                            .foregroundColor(.appWhite88)
                            .lineSpacing(4)
                            .contentTransition(.opacity)
                    }

                    HStack {
                        OnboardingPaginationDots(count: pages.count, activeIndex: index)

                        Spacer()

                        Button(action: advance) {
                            HStack(spacing: 10) {
                                Text(current.buttonTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .contentTransition(.opacity)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .padding(.leading, 24)
                            .padding(.trailing, 20)
                            .padding(.vertical, 12)
                        }
                        .pillStyle(fill: .white, border: .appBorder)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
            .animation(.easeInOut(duration: AppMotion.standard), value: step)
        }
    }

    private func advance() {
        if step < pages.count {
            step += 1
        } else {
            onFinished()
        }
    }
}

private struct OnboardingPhotoBackground: View {
    let imageName: String
    var showGradient: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let uiImage = UIImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    LinearGradient.appAuthImageFallback
                }

                if showGradient {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.30),
                            .init(color: .black.opacity(0.75), location: 0.60),
                            .init(color: .black, location: 0.90)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct OnboardingPaginationDots: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == activeIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: index == activeIndex ? 24 : 8, height: 8)
            }
        }
    }
}

#Preview {
    PostRegisterOnboardingView(onFinished: {})
}

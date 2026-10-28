import SwiftUI

/// Step 1 — "Book a shelter. In an instant". A collage of pod photos
/// fading into the ground color, with the title and a single pill over it.
struct OnboardingWelcomeStep: View {
    var onStart: () -> Void

    var body: some View {
        ZStack {
            Color.onbBackground.ignoresSafeArea()

            OnboardingCollage()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 6) {
                    Text("Book a shelter.")
                    Text("In an instant")
                }
                .font(OnboardingFont.title)
                .foregroundColor(.onbText)

                Text("Ask Lenny about your trip, select and you’re all set.")
                    .font(OnboardingFont.compact)
                    .foregroundColor(.onbSubtitle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 215)
                    .padding(.top, 24)

                OnboardingPillButton(title: "Touch to start →", action: onStart)
                    .frame(width: 209)
                    .padding(.top, 48)
                    .padding(.bottom, 40)
            }
        }
    }
}

/// The photo wall, laid out on the Figma frame's 393x852 canvas and scaled
/// to the screen width. The lower half is blurred and faded into the
/// ground color so the text and button sit on a calm surface. The photos
/// drift slowly behind it; Reduce Motion freezes them.
private struct OnboardingCollage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let canvas = CGSize(width: 393, height: 852)

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / canvas.width
            TimelineView(.animation(paused: reduceMotion)) { context in
                // One clock for both copies of the wall so the blurred
                // layer stays locked to the sharp one.
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    wall(at: time)
                        .drawingGroup()

                    // Only the lower half is ever visible blurred, so blur
                    // just that half — it's re-rendered every frame.
                    wall(at: time)
                        .offset(y: -canvas.height / 2)
                        .frame(width: canvas.width, height: canvas.height / 2, alignment: .topLeading)
                        .clipped()
                        .drawingGroup()
                        .blur(radius: 6)
                        .mask(
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        )
                        .offset(y: canvas.height / 2)

                    LinearGradient(
                        stops: [.init(color: .clear, location: 0.5), .init(color: .onbBackground, location: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
            }
        }
    }

    private func wall(at time: TimeInterval) -> some View {
        ZStack(alignment: .topLeading) {
            // The outlines drift less than the photos, so the two layers
            // slide against each other like frames at different depths.
            ForEach(Self.outlines.indices, id: \.self) { index in
                let frame = Self.outlines[index]
                let drift = Self.drift(at: time, index: index + 3, amplitude: 6)
                Rectangle()
                    .strokeBorder(Color.onbCollageOutline, lineWidth: 0.5)
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX + drift.width, y: frame.minY + drift.height)
            }

            ForEach(Self.photos.indices, id: \.self) { index in
                let photo = Self.photos[index]
                let drift = Self.drift(at: time, index: index, amplitude: 14)
                CollagePhoto(name: photo.name, size: photo.frame.size, tallCrop: photo.tallCrop)
                    .offset(x: photo.frame.minX + drift.width, y: photo.frame.minY + drift.height)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
    }

    /// A looping wander on a Lissajous-style path. Each item gets its
    /// own speed and phase from its index, so nothing moves in lockstep.
    private static func drift(at time: TimeInterval, index: Int, amplitude: CGFloat) -> CGSize {
        let speed = 0.5 + 0.1 * Double(index % 3)
        let phase = Double(index) * 1.7
        return CGSize(
            width: amplitude * CGFloat(sin(time * speed + phase)),
            height: amplitude * CGFloat(cos(time * speed * 0.8 + phase * 1.3))
        )
    }

    private struct Photo {
        let name: String
        let frame: CGRect
        /// The Figma frame shows a window into a tall photo (178% height,
        /// 41% up) instead of a plain fill crop.
        var tallCrop = false
    }

    private static let photos: [Photo] = [
        Photo(name: "ObChalet", frame: CGRect(x: 152, y: 349, width: 200, height: 146)),
        Photo(name: "ObDeck", frame: CGRect(x: 29, y: 737, width: 200, height: 168), tallCrop: true),
        Photo(name: "ObHillside", frame: CGRect(x: -44, y: 67, width: 200, height: 150)),
        Photo(name: "ObDeck", frame: CGRect(x: 199, y: 118, width: 200, height: 168), tallCrop: true),
        Photo(name: "ObHut", frame: CGRect(x: 232, y: 597, width: 200, height: 112)),
        Photo(name: "ObRocks", frame: CGRect(x: -44, y: 532, width: 200, height: 143)),
        Photo(name: "ObRidge", frame: CGRect(x: 235, y: -49, width: 200, height: 112)),
        Photo(name: "ObTerrace", frame: CGRect(x: -21, y: 286, width: 100, height: 150)),
    ]

    private static let outlines: [CGRect] = [
        CGRect(x: 181, y: 100, width: 265, height: 204),
        CGRect(x: 129, y: 328, width: 247, height: 187),
        CGRect(x: -145, y: 266, width: 247, height: 187),
        CGRect(x: -74, y: 47, width: 247, height: 187),
        CGRect(x: 213, y: -105, width: 247, height: 187),
    ]
}

private struct CollagePhoto: View {
    let name: String
    let size: CGSize
    let tallCrop: Bool

    var body: some View {
        Group {
            if tallCrop {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height * 1.7816)
                    .offset(y: -size.height * 0.4103)
                    .frame(width: size.width, height: size.height, alignment: .top)
            } else {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
            }
        }
        .clipped()
    }
}

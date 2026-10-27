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
/// ground color so the text and button sit on a calm surface.
private struct OnboardingCollage: View {
    private let canvas = CGSize(width: 393, height: 852)

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / canvas.width
            ZStack(alignment: .topLeading) {
                wall

                wall
                    .blur(radius: 6)
                    .mask(
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0.5), .init(color: .black, location: 1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

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

    private var wall: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.outlines.indices, id: \.self) { index in
                let frame = Self.outlines[index]
                Rectangle()
                    .strokeBorder(Color.onbCollageOutline, lineWidth: 0.5)
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
            }

            ForEach(Self.photos.indices, id: \.self) { index in
                let photo = Self.photos[index]
                CollagePhoto(name: photo.name, size: photo.frame.size, tallCrop: photo.tallCrop)
                    .offset(x: photo.frame.minX, y: photo.frame.minY)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
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

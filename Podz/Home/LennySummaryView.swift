import SwiftUI

/// The end of the Lenny plan: the pod picked at each stop, in route order.
/// Flat rows with a hairline, same page recipe as the pages Profile opens
/// (`design.md`): a 30 semiBold title, the list behind a fade into the
/// ground, and the back pill with the page's action beside it. Tap a row to
/// look at that pod.
struct LennySummaryView: View {
    struct Entry: Identifiable {
        let stopName: String
        let pod: Pod
        var id: UUID { pod.id }
    }

    let entries: [Entry]
    let photoURLs: [UUID: String]
    var onBack: () -> Void
    var onOpenPod: (Pod) -> Void
    var onDone: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your plan")
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(-0.6)
                        .foregroundColor(.homeText)
                        .padding(.horizontal, 24)
                        .padding(.top, 25)
                        .padding(.bottom, 16)

                    ForEach(entries) { entry in
                        row(entry)
                    }

                    Color.clear.frame(height: 190)
                }
            }

            // Fade into the ground behind the buttons.
            LinearGradient(
                stops: [.init(color: .clear, location: 0.5), .init(color: .homeBackground, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            HStack(spacing: 13) {
                DetailBackButton(action: onBack)
                DetailTextButton(title: "Done", action: onDone)
            }
            .padding(.horizontal, 24)
            // The cover respects the safe area, so 40 here is the 74 from
            // the bottom edge every control stack uses.
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
    }

    private func row(_ entry: Entry) -> some View {
        Button { onOpenPod(entry.pod) } label: {
            HStack(spacing: 16) {
                Color.clear
                    .frame(width: 72, height: 72)
                    .overlay { PodPhoto(url: photoURLs[entry.pod.id]) }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.pod.name)
                        .font(AppFont.semiBoldLabel(16))
                        .foregroundColor(.homeText)
                        .lineLimit(1)
                    Text(entry.stopName)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.homeText.opacity(0.08)).frame(height: 1).padding(.horizontal, 24)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

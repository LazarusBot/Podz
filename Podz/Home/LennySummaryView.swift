import SwiftUI

/// The end of the Lenny plan: the pod picked at each stop, in route order,
/// along the same numbered line as the search's steps. Same page recipe as
/// the pages Profile opens (`design.md`): a 30 semiBold title, the list
/// behind a fade into the ground, and the back pill with the page's action
/// beside it. Tap a row to look at that pod.
struct LennySummaryView: View {
    struct Entry: Identifiable {
        let stopName: String
        let pod: Pod
        /// "3.2 km away · 24 beds"; may be empty.
        let detail: String
        let isLennysPick: Bool
        var id: UUID { pod.id }
    }

    let entries: [Entry]
    let photoURLs: [UUID: String]
    var onBack: () -> Void
    var onOpenPod: (Pod) -> Void
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let dotSize: CGFloat = 24
    private let photoSize: CGFloat = 88

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

                    Text(subtitle)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, 28)

                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry, number: index + 1, isLast: index == entries.count - 1)
                            // Each stop settles in a beat after the one before.
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .offset(y: appeared || reduceMotion ? 0 : 14)
                            .animation(.smooth(duration: 0.5).delay(0.08 * Double(index)), value: appeared)
                    }

                    Color.clear.frame(height: 190)
                }
            }

            BottomFade()

            HStack(spacing: 13) {
                DetailBackButton(action: onBack)
                DetailTextButton(title: "Done", isHighlighted: true, action: onDone)
            }
            .padding(.horizontal, 24)
            // The cover respects the safe area, so 40 here is the 74 from
            // the bottom edge every control stack uses.
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .onAppear { appeared = true }
    }

    private var subtitle: String {
        let stops = entries.count
        return "\(stops) \(stops == 1 ? "stop" : "stops"), one pod each"
    }

    /// A numbered dot on the line, then the stop, the pod and its photo.
    private func row(_ entry: Entry, number: Int, isLast: Bool) -> some View {
        Button { onOpenPod(entry.pod) } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Text("\(number)")
                        .font(AppFont.semiBoldLabel(12))
                        .foregroundColor(.homeBackground)
                        .frame(width: dotSize, height: dotSize)
                        .background(Color.homeText, in: Circle())
                    if !isLast {
                        Rectangle()
                            .fill(Color.homeText.opacity(0.25))
                            .frame(width: 1)
                            .mask {
                                // The dotted line the search's steps use.
                                VStack(spacing: 3) {
                                    ForEach(0..<60, id: \.self) { _ in Rectangle().frame(height: 2) }
                                }
                            }
                            .frame(maxHeight: .infinity)
                            .padding(.top, 6)
                    }
                }
                .frame(width: dotSize)

                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.stopName)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(1)
                        .frame(height: dotSize, alignment: .leading)

                    HStack(alignment: .center, spacing: 16) {
                        Color.clear
                            .frame(width: photoSize, height: photoSize)
                            .overlay { PodPhoto(url: photoURLs[entry.pod.id]) }
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.pod.name)
                                .font(AppFont.semiBoldLabel(17))
                                .foregroundColor(.homeText)
                                .lineLimit(2)
                            if !entry.detail.isEmpty {
                                Text(entry.detail)
                                    .font(AppFont.regularLabel(13))
                                    .foregroundColor(.homeSubtitle)
                                    .lineLimit(1)
                            }
                            if entry.isLennysPick {
                                HStack(spacing: 6) {
                                    Image("lenny")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 10, height: 10)
                                        .foregroundColor(.homeBackground)
                                        .frame(width: 18, height: 18)
                                        .background(Color.homeText, in: Circle())
                                    Text("Lenny's pick")
                                        .font(AppFont.semiBoldLabel(12))
                                        .foregroundColor(.homeText)
                                }
                                .padding(.top, 3)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, isLast ? 0 : 28)
                }
            }
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

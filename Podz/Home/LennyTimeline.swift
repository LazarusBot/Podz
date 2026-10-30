import SwiftUI

/// The steps Lenny works through (Paper "LennySearch" frames): a dot per
/// step on a dotted line that fades down, the step's name (13 semiBold) and
/// a caption (11) beside it. A done step is full strength; the one still
/// running is quiet.
struct LennyTimeline: View {
    let steps: [LennySearchViewModel.StepInfo]

    private let dotSize: CGFloat = 18
    private let rowHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                let isLast = index == steps.count - 1
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        dot(isDone: step.isDone)
                        if !isLast {
                            DottedLine()
                                .stroke(Color.homeText.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                                .padding(.vertical, 6)
                        }
                    }
                    .frame(width: dotSize)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(step.title)
                            .font(AppFont.semiBoldLabel(13))
                            .foregroundColor(step.isDone ? .homeText : .homeSubtitle)
                        if !step.subtitle.isEmpty {
                            Text(step.subtitle)
                                .font(AppFont.regularLabel(11))
                                .foregroundColor(.homeSubtitle)
                        }
                    }
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, minHeight: isLast ? 0 : rowHeight, alignment: .topLeading)
                }
                .animation(.easeOut(duration: 0.3), value: step.isDone)
            }
        }
    }

    /// A solid dot in a soft ring: the ring is always there, the dot fills
    /// in when the step is done.
    private func dot(isDone: Bool) -> some View {
        ZStack {
            Circle().fill(Color.homeText.opacity(0.12))
            Circle()
                .fill(Color.homeText.opacity(isDone ? 1 : 0.3))
                .padding(4)
        }
        .frame(width: dotSize, height: dotSize)
    }
}

private struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

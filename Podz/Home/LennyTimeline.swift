import SwiftUI

/// The steps Lenny works through (Paper "LennySearch" frames): a dot per
/// step on a dotted line, the step's name (13 semiBold) and a caption (11)
/// beside it. All of it is on screen from the first frame; a step fills in
/// as it finishes.
///
/// To make the wait lighter: the step in progress has a dot that breathes,
/// and its caption rotates through little lines of Lenny's. A finished
/// step's dot pops in with a tap, and the line below it draws itself down
/// to the next one. Reduce Motion keeps the state changes and drops the
/// looping motion.
struct LennyTimeline: View {
    let steps: [LennySearchViewModel.StepInfo]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dotSize: CGFloat = 18
    private let rowHeight: CGFloat = 96

    /// What a step says while it's running, by step. The last one is the long
    /// wait, so it has the most to say.
    private static let waitingLines: [Int: [String]] = [
        0: ["Reading your itinerary…", "Spotting peaks and lakes…"],
        1: ["Peeking into the huts…", "Counting free beds…"],
        2: [
            "Can take up to 2 minutes…",
            "Asking the marmots for tips…",
            "Lacing up the boots…",
            "Checking the sunrise views…",
            "Packing one very small snack…",
            "Following the trail markers…"
        ]
    ]

    /// The step in progress: the first one not done.
    private var activeID: Int? { steps.first { !$0.isDone }?.id }
    private var doneCount: Int { steps.filter(\.isDone).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                let isLast = index == steps.count - 1
                let isActive = step.id == activeID
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        dot(isDone: step.isDone, isActive: isActive)
                        if !isLast {
                            connector(isDrawn: step.isDone)
                        }
                    }
                    .frame(width: dotSize)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(step.title)
                            .font(AppFont.semiBoldLabel(13))
                            .foregroundColor(step.isDone || isActive ? .homeText : .homeSubtitle)
                            .contentTransition(.opacity)
                        StepCaption(
                            text: step.subtitle,
                            lines: captionLines(for: step, isActive: isActive),
                            isRotating: isActive && !reduceMotion
                        )
                    }
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, minHeight: isLast ? 0 : rowHeight, alignment: .topLeading)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: steps.map(\.title))
        .sensoryFeedback(.impact(weight: .light), trigger: doneCount)
    }

    /// Running: every line, rotating. Still waiting: just the first, so the
    /// layout is complete before anything starts. Done: the result's own caption.
    private func captionLines(for step: LennySearchViewModel.StepInfo, isActive: Bool) -> [String] {
        let lines = Self.waitingLines[step.id] ?? []
        if isActive { return lines }
        return step.isDone ? [] : Array(lines.prefix(1))
    }

    /// A ring that's always there, with a solid dot inside: quiet while the
    /// step waits, breathing while it runs, popped to full when it's done.
    private func dot(isDone: Bool, isActive: Bool) -> some View {
        ZStack {
            Circle().fill(Color.homeText.opacity(0.12))
            if isActive && !reduceMotion {
                Circle()
                    .fill(Color.homeText.opacity(0.12))
                    .phaseAnimator([false, true]) { view, grown in
                        view
                            .scaleEffect(grown ? 1.9 : 1)
                            .opacity(grown ? 0 : 1)
                    } animation: { _ in .easeOut(duration: 1.1) }
            }
            Circle()
                .fill(Color.homeText.opacity(isDone ? 1 : isActive ? 0.6 : 0.3))
                .padding(4)
                .scaleEffect(isDone ? 1 : 0.8)
        }
        .frame(width: dotSize, height: dotSize)
        .animation(.bouncy(duration: 0.45), value: isDone)
        .animation(.easeOut(duration: 0.3), value: isActive)
    }

    /// The dotted line down to the next step; a solid line draws over it
    /// once this step is done.
    private func connector(isDrawn: Bool) -> some View {
        ZStack(alignment: .top) {
            VLine()
                .stroke(Color.homeText.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            VLine()
                .trim(from: 0, to: isDrawn ? 1 : 0)
                .stroke(Color.homeText, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .animation(.easeOut(duration: 0.6), value: isDrawn)
        }
        .frame(width: 1)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 6)
    }
}

/// A step's caption. Once the step is done it's the real result (the stops
/// found); while it runs it rotates through `lines`. One line of height is
/// always reserved, so nothing below it jumps.
private struct StepCaption: View {
    let text: String
    let lines: [String]
    let isRotating: Bool

    @State private var index = 0

    private var shown: String {
        if !text.isEmpty { return text }
        return lines.isEmpty ? " " : lines[index % lines.count]
    }

    var body: some View {
        Text(shown)
            .font(AppFont.regularLabel(11))
            .foregroundColor(.homeSubtitle)
            .id(shown)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .frame(maxWidth: .infinity, minHeight: 14, alignment: .topLeading)
            .clipped()
            .task(id: isRotating) {
                guard isRotating, lines.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    if Task.isCancelled { return }
                    withAnimation(.smooth(duration: 0.4)) { index += 1 }
                }
            }
    }
}

private struct VLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

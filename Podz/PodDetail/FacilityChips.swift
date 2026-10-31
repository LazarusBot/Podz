import SwiftUI

/// What a hut has on site, as flat `homePill` capsules that wrap onto as many
/// centered lines as they need ("Meals", "Showers", "Drinking water").
struct FacilityChips: View {
    let facilities: [String]

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(facilities, id: \.self) { facility in
                Text(facility)
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.homeText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.homePill, in: Capsule())
            }
        }
    }
}

/// "Unverified" under a listed hut's name: its information comes from
/// OpenStreetMap, nobody at Podz has checked it. A partner has no badge.
struct UnverifiedBadge: View {
    var body: some View {
        Text("Unverified")
            .font(AppFont.regularLabel(13))
            .foregroundColor(.homeSubtitle)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.homePill, in: Capsule())
            .accessibilityLabel("Unverified listing")
    }
}

/// Items left to right, wrapping to a new centered line when the width runs out.
private struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    /// The indices of each line, given the width there is.
    private func lines(sizes: [CGSize], width: CGFloat) -> [[Int]] {
        var lines: [[Int]] = [[]]
        var x: CGFloat = 0
        for index in sizes.indices {
            if x > 0 && x + sizes[index].width > width {
                lines.append([])
                x = 0
            }
            lines[lines.count - 1].append(index)
            x += sizes[index].width + spacing
        }
        return lines
    }

    private func lineWidth(_ line: [Int], sizes: [CGSize]) -> CGFloat {
        var total: CGFloat = spacing * CGFloat(max(line.count - 1, 0))
        for index in line { total += sizes[index].width }
        return total
    }

    private func lineHeight(_ line: [Int], sizes: [CGSize]) -> CGFloat {
        var tallest: CGFloat = 0
        for index in line { tallest = max(tallest, sizes[index].height) }
        return tallest
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes: [CGSize] = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = lines(sizes: sizes, width: proposal.width ?? .infinity)
        var height: CGFloat = lineSpacing * CGFloat(max(rows.count - 1, 0))
        var widest: CGFloat = 0
        for row in rows {
            height += lineHeight(row, sizes: sizes)
            widest = max(widest, lineWidth(row, sizes: sizes))
        }
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes: [CGSize] = subviews.map { $0.sizeThatFits(.unspecified) }
        var y = bounds.minY
        for row in lines(sizes: sizes, width: bounds.width) {
            var x = bounds.minX + (bounds.width - lineWidth(row, sizes: sizes)) / 2
            for index in row {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += sizes[index].width + spacing
            }
            y += lineHeight(row, sizes: sizes) + lineSpacing
        }
    }
}

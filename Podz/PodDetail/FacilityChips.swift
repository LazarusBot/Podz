import SwiftUI

/// What a hut has on site, as flat `homePill` capsules that wrap onto as many
/// centered lines as they need ("Meals", "Showers", "Drinking water").
struct FacilityChips: View {
    let facilities: [String]
    /// Lines centered (the stack) or flush left (the sections).
    var isCentered = true

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8, isCentered: isCentered) {
            ForEach(facilities, id: \.self) { facility in
                T(facility)
                    .font(AppFont.regularLabel(14))
                    .foregroundColor(.homeText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.homePill, in: Capsule())
            }
        }
    }
}

/// The trust mark under a hut's name, flat `homePill` like every chip. A partner
/// hut is **Verified** (a check in a `homeText` disc): its beds, prices and
/// availability come from the hut itself. A listed hut is **Unverified** (an
/// empty disc with a question mark): its information comes from OpenStreetMap, nobody at Podz has
/// checked it. Tap either for the plain explanation.
struct TrustBadge: View {
    let isVerified: Bool

    var body: some View {
        HStack(spacing: 7) {
            if isVerified {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.homeBackground)
                    .frame(width: 14, height: 14)
                    .background(Color.homeText, in: Circle())
            } else {
                // The check's counterpart: a question mark in an empty disc.
                Text("?")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.homeSubtitle)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Color.homeSubtitle, lineWidth: 1.2))
            }
            T(isVerified ? "Verified" : "Unverified")
                .font(AppFont.regularLabel(13))
                .foregroundColor(isVerified ? .homeText : .homeSubtitle)
                .lineLimit(1)
                .fixedSize()
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.homeSubtitle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.homePill, in: Capsule())
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tr(isVerified ? "Verified by Podz" : "Unverified listing"))
    }
}

/// "Open now" / "Closed until June" with a dot. Open is quiet (flat `homePill`,
/// a `homeText` dot: good news doesn't shout). **Closed is red** (`alertFill`
/// inside, `alertInk` for the dot, the label and a 1pt outline): red is for
/// what can cancel the trip. The dot is the only plain round mark here, so it
/// can't be mistaken for the trust badge.
struct OpenStatusChip: View {
    let status: OpeningStatus.Result

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(status.isOpen ? Color.homeText : Color.alertInk)
                .frame(width: 8, height: 8)
            T(status.label)
                .font(AppFont.regularLabel(13))
                .foregroundColor(status.isOpen ? .homeText : .alertInk)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(status.isOpen ? Color.homePill : Color.alertFill, in: Capsule())
        .overlay { if !status.isOpen { Capsule().strokeBorder(Color.alertInk.opacity(0.45), lineWidth: 1) } }
        .accessibilityElement(children: .combine)
    }
}

/// Under the name: whether it's open (when the hours say so) and whether
/// Podz has checked the hut (**Verified** for a partner, **Unverified** for a
/// listed one, both tappable for the explanation).
struct PodStatusRow: View {
    let pod: Pod
    var isCentered = true

    @State private var explains = false

    private var status: OpeningStatus.Result? { OpeningStatus.evaluate(pod.openingHours) }

    @ViewBuilder
    private var chips: some View {
        if let status { OpenStatusChip(status: status) }
        Button { explains = true } label: { TrustBadge(isVerified: pod.isBookable) }
            .buttonStyle(.plain)
    }

    var body: some View {
        // Side by side; when the room is short (beside the thumbnail) the chips
        // stack instead of squeezing, so each is as long as its text.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: isCentered ? .center : .leading, spacing: 8) { chips }
        }
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
        .alert(tr(pod.isBookable ? "Verified by Podz" : "Not checked by Podz"), isPresented: $explains) {
            Button(tr("OK"), role: .cancel) {}
        } message: {
            Text(tr(pod.isBookable
                ? "This hut books through Podz: its beds, prices and availability come from the hut itself."
                : "This hut comes from OpenStreetMap and nobody at Podz has checked its details. Call ahead before you go."))
        }
    }
}

/// Items left to right, wrapping to a new centered line when the width runs out.
private struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var isCentered = true

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
            var x = bounds.minX + (isCentered ? (bounds.width - lineWidth(row, sizes: sizes)) / 2 : 0)
            for index in row {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += sizes[index].width + spacing
            }
            y += lineHeight(row, sizes: sizes) + lineSpacing
        }
    }
}

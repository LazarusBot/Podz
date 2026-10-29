import SwiftUI

/// A single "label + helper text ... control" row, separated by a
/// dashed divider below it. Lives inline in the search pill's Filters
/// panel — no horizontal padding of its own, since the pill already
/// insets everything else uniformly.
struct FilterRow<Control: View>: View {
    let title: String
    let helper: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Explicit sizes — itemTitle()/itemHelper() default to
                    // 10pt/8pt, which reads as an afterthought next to
                    // everything else in this pill (18pt chip labels,
                    // 15pt text field, 18pt Save button).
                    Text(title)
                        .font(AppFont.itemTitle(16))
                        .foregroundColor(.appTextPrimary)
                    Text(helper)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.appTextSecondary)
                }
                // Matches the Save button's own text inset (its
                // horizontal padding is 14pt, same as the pill's other
                // buttons/chips) so this row's text actually lines up
                // with it, instead of sitting flush with the pill's edge.
                .padding(.leading, 14)
                Spacer()
                control()
            }

            DashedDivider()
                .padding(.top, 12)
        }
    }
}

/// A dashed, full-width horizontal rule in `.appBorder` — used between
/// filter rows instead of a plain `Divider()`, which can't be dashed.
struct DashedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .frame(height: 1)
    }
}

/// The small "Lenny" mark (12x12), reused in the chip and the search

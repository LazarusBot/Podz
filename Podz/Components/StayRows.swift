import SwiftUI

/// The rows the booking sheets are made of (`design.md`): a 16 label, the
/// answer at the trailing edge, a hairline above (`homeText` at 8%). 60 high.
struct StayStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    /// "guest" / "night": the answer reads "2 guests".
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(AppFont.regularLabel(16))
                .foregroundColor(.homeText)
            Spacer(minLength: 12)
            stepButton("minus", enabled: value > range.lowerBound) { value -= 1 }
            Text("\(value) \(value == 1 ? unit : unit + "s")")
                .font(AppFont.semiBoldLabel(16))
                .foregroundColor(.homeText)
                .frame(minWidth: 84)
                .contentTransition(.numericText())
            stepButton("plus", enabled: value < range.upperBound) { value += 1 }
        }
        .frame(height: 60)
        .stayHairline()
        .animation(.smooth(duration: 0.2), value: value)
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.homeText)
                .frame(width: 38, height: 38)
                .background(Color.homePill, in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }
}

struct StayDateRow: View {
    let label: String
    @Binding var date: Date

    var body: some View {
        HStack {
            Text(label)
                .font(AppFont.regularLabel(16))
                .foregroundColor(.homeText)
            Spacer()
            DatePicker(label, selection: $date, in: Date()..., displayedComponents: .date)
                .labelsHidden()
                .tint(.homeText)
        }
        .frame(height: 60)
        .stayHairline()
    }
}

/// A label with its value, for the summary under the pickers.
struct StaySummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(AppFont.regularLabel(16))
                .foregroundColor(.homeText)
            Spacer(minLength: 12)
            Text(value)
                .font(AppFont.regularLabel(16))
                .foregroundColor(.homeSubtitle)
                .lineLimit(1)
        }
        .frame(height: 52)
        .stayHairline()
    }
}

extension View {
    /// The row's hairline, at its top edge.
    func stayHairline() -> some View {
        overlay(alignment: .top) { Rectangle().fill(Color.homeText.opacity(0.08)).frame(height: 1) }
    }
}

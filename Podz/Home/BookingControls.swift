import SwiftUI

/// The booking flow's control stack (`BookingFlow`): at rest the back pill and
/// the right-hand pill (a plain button for the question, then Reserve, then
/// View reservations); while a picker is open it takes the whole stack: a round
/// minus, the answer, a round plus and the continue button.
struct BookingControlStack: View {
    @ObservedObject var flow: BookingFlow
    /// Leaves the flow: from the first question, or once it's booked.
    var onLeave: () -> Void
    /// After booking: go look at the reservations.
    var onViewReservations: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            if flow.isPickerOpen {
                picker
                    .transition(.opacity)
            } else {
                DetailBackButton { flow.back(onLeave: onLeave) }
                primaryPill
            }
        }
        .animation(.smooth(duration: 0.35), value: flow.stage)
        .animation(.smooth(duration: 0.35), value: flow.isPicking)
        .animation(.smooth(duration: 0.35), value: flow.nightsScope)
        .animation(.smooth(duration: 0.35), value: flow.status)
        .animation(.smooth(duration: 0.35), value: flow.guestsConfirmed)
        .animation(.smooth(duration: 0.35), value: flow.dateConfirmed)
        .animation(.smooth(duration: 0.35), value: flow.nightsConfirmed)
        .bookingDateSheet(flow)
    }

    /// The right-hand pill at rest: the question as a plain button, then
    /// Reserve / View reservations.
    @ViewBuilder
    private var primaryPill: some View {
        switch (flow.status, flow.stage) {
        case _ where flow.bookableCount == 0:
            // All listed: nothing to reserve; the rows open each hut.
            DetailTextButton(title: "Back to plan") { flow.back(onLeave: onLeave) }
        case (.booked, _):
            DetailTextButton(title: "View reservations", isHighlighted: true, action: onViewReservations)
        case (.booking, _):
            DetailTextButton(title: flow.mode == .external ? "Adding…" : "Reserving…", action: {})
                .disabled(true)
                .opacity(0.45)
        case (_, .guests):
            DetailTextButton(title: flow.guestsConfirmed ? flow.guestsText : "Add guest") { flow.isPicking = true }
        case (_, .date):
            DetailTextButton(title: flow.dateConfirmed ? flow.dateText : "Add date") { flow.isPicking = true }
        case (_, .nights):
            DetailTextButton(title: flow.nightsConfirmed ? flow.nightsText : "Add nights") { flow.isPicking = true }
        case (_, .review):
            DetailTextButton(title: flow.mode == .external ? "Add to my list" : "Reserve", isHighlighted: true, action: flow.reserve)
        }
    }

    /// The picker, across the whole stack: one big pill holding a round minus,
    /// the answer and a round plus (the two buttons are 75, 4 in from the
    /// pill's edge all round), then continue beside it.
    private var picker: some View {
        HStack(spacing: 13) {
            HStack(spacing: 0) {
                pickerButton(accessibilityLabel: lessLabel, action: flow.decrease) { MinusGlyph() }

                Group {
                    switch flow.stage {
                    case .guests:
                        pickerAnswer("\(flow.guests)", caption: flow.guests == 1 ? "guest" : "guests")
                    case .nights:
                        let shown = flow.nightsScope.map(flow.nightsFor) ?? flow.nights
                        pickerAnswer("\(shown)", caption: nightsCaption(shown))
                    default:
                        // Tap the date for the calendar, to jump further.
                        Button { flow.showsDatePicker = true } label: {
                            VStack(spacing: 2) {
                                Text(flow.startDate.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(AppFont.semiBoldLabel(16))
                                    .foregroundColor(.homeText)
                                Text(flow.startDate.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(AppFont.regularLabel(12))
                                    .foregroundColor(.homeSubtitle)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start date, \(flow.startDate.formatted(.dateTime.weekday(.wide).day().month(.wide))). Opens the calendar")
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

                pickerButton(accessibilityLabel: moreLabel, action: flow.increase) { PlusGlyph() }
            }
            // 4 all round, so the 75 circles sit evenly inside the 83 pill.
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 83)
            .background(DetailPill())

            continueButton
        }
    }

    private func nightsCaption(_ shown: Int) -> String {
        let unit = shown == 1 ? "night" : "nights"
        return flow.nightsScope == nil && !flow.isSingle ? unit + " per stop" : unit
    }

    /// A − or + at the end of the picker pill: a 75 circle in the classic
    /// pill grey with a 0.5pt edge so it reads against the pill, and a thin
    /// vector like the back chevron's.
    private func pickerButton<Glyph: Shape>(
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder glyph: () -> Glyph
    ) -> some View {
        Button(action: action) {
            glyph()
                .stroke(Color.homeText, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 12, height: 12)
                .frame(width: 75, height: 75)
                .background(Color.homePill, in: Circle())
                .overlay(Circle().strokeBorder(Color.homeText.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var lessLabel: String {
        switch flow.stage {
        case .guests: "Fewer guests"
        case .nights: "Fewer nights"
        default: "Day earlier"
        }
    }

    private var moreLabel: String {
        switch flow.stage {
        case .guests: "More guests"
        case .nights: "More nights"
        default: "Day later"
        }
    }

    private func pickerAnswer(_ value: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.semiBoldLabel(24))
                .foregroundColor(.homeText)
            Text(caption)
                .font(AppFont.regularLabel(12))
                .foregroundColor(.homeSubtitle)
        }
    }

    /// Answers the question and moves on: the back pill's twin, with its
    /// chevron turned around, inverted because it's the one to press.
    private var continueButton: some View {
        Button(action: flow.confirm) {
            // The back pill's chevron, turned around: same glyph, same size.
            DetailBackChevron()
                .stroke(Color.homeBackground, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 12)
                .scaleEffect(x: -1)
                .frame(width: 83, height: 83)
                .background(Circle().fill(Color.homeText))
        }
        .buttonStyle(TapScaleButtonStyle())
        .accessibilityLabel("Continue")
    }
}

/// What's been decided so far, as flat chips. Tap one to change that answer
/// on its own; the others stay as they are.
struct BookingChips: View {
    @ObservedObject var flow: BookingFlow

    var body: some View {
        if flow.hasChoices {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if flow.guestsConfirmed { chip(flow.guestsText, stage: .guests) }
                    if flow.dateConfirmed { chip(flow.dateText, stage: .date) }
                    if flow.nightsConfirmed { chip(flow.nightsText, stage: .nights) }
                }
                .padding(.horizontal, 24)
            }
            .transition(.opacity)
        }
    }

    private func chip(_ title: String, stage target: BookingFlow.Stage) -> some View {
        Button { flow.change(target) } label: {
            Text(title)
                .font(AppFont.regularLabel(14))
                .foregroundColor(.homeText)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(Capsule().fill(Color.homePill))
        }
        .buttonStyle(TapScaleButtonStyle())
        .disabled(flow.status == .booked)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .accessibilityLabel("\(title). Change")
    }
}

/// A small caption under Lenny's bubble, not a button-shaped control: the
/// quick reply of the nights question ("Set each stop").
struct BookingQuickReply: View {
    let reply: BookingFlow.QuickReply

    var body: some View {
        Button(action: reply.action) {
            HStack(spacing: 5) {
                Text(reply.title)
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .underline(color: Color.homeSubtitle.opacity(0.5))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.homeSubtitle)
            }
            // A comfortable tap area for a small caption.
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// The calendar, in a small sheet with the same Done pill as everywhere.
    func bookingDateSheet(_ flow: BookingFlow) -> some View {
        modifier(BookingDateSheet(flow: flow))
    }
}

private struct BookingDateSheet: ViewModifier {
    @ObservedObject var flow: BookingFlow

    func body(content: Content) -> some View {
        content.sheet(isPresented: $flow.showsDatePicker) {
            VStack(spacing: 0) {
                DatePicker("", selection: $flow.startDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(.homeText)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                Spacer(minLength: 0)

                DetailTextButton(title: "Done", isHighlighted: true) { flow.showsDatePicker = false }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .background(Color.homeBackground)
            .presentationDetents([.height(560)])
            .presentationDragIndicator(.hidden)
        }
    }
}

/// The thin "-" and "+" of the picker, drawn like the back chevron: 1.5 round
/// strokes in a 12 x 12 box.
private struct MinusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct PlusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = MinusGlyph().path(in: rect)
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

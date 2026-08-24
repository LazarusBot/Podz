import SwiftUI

/// One chip in the category scroller. `isSelected` matches the black-filled
/// "Hikes" state in Figma; unselected chips are white pills.
struct CategoryChip: View {
    let title: String
    var count: Int? = nil
    var isSelected: Bool = false
    var icon: String? = nil          // SF Symbol shown before the label
    var action: () -> Void = {}

    /// Black weight is reserved for the selected state; Lenny keeps it
    /// regardless since it's an action chip, not a filter toggle — it
    /// never actually becomes `isSelected` (tapping it fires an action
    /// rather than setting the selection).
    private var labelFont: Font {
        (isSelected || title == "Lenny") ? AppFont.pillLabel(18) : AppFont.pillLabelMedium(18)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    ChipIcon(name: icon, isSelected: isSelected)
                }

                Text(title)
                    .font(labelFont)
                    .foregroundColor(isSelected ? .white : .black)

                if let count {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isSelected ? .black : .white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(isSelected ? Color.white : Color.black))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .pillStyle(fill: isSelected ? .appAccentBlack : .white, border: .appBorder)
    }
}

/// Custom asset if present
/// falls back to SF Symbol otherwise — same pattern as TabIcon.
private struct ChipIcon: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        Group {
            if UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
            } else {
                // SF Symbols aren't resizable — without an explicit size
                // they render at the ambient ~17pt text size and overflow
                // the 15x15 box below instead of being scaled into it,
                // which crowds the label next to them.
                Image(systemName: name)
                    .font(.system(size: 15, weight: .medium))
            }
        }
        .frame(width: 15, height: 15)
        .foregroundStyle(isSelected ? Color.white : Color.black)
    }
}

/// Home's top search field — a single pill that carries all four of
/// Lenny's phases, rather than handing off to a separate component per
/// phase. Idle/editing show an editable text field: plain location
/// search, or — once the "Lenny" chip is tapped — Lenny's itinerary
/// text (`LennySearchViewModel.itineraryText`), with the leading icon,
/// placeholder, and chip label swapping to match. Tapping the field
/// expands the pill to roughly double height, revealing a bottom row:
/// the mode-toggle chip + a "Filters" button on the left, a submit
/// button on the right. Once a Lenny query is actually submitted, the
/// field is replaced by status text (searching/results) and the pill
/// chrome drops away — that text isn't editable, so looking like a
/// text field would be misleading. Tapping "Filters" folds a filter
/// panel open right below that row, in the same pill, instead of
/// presenting a separate sheet — values live in `HomeFiltersState.shared`
/// so `HomeView` can read them. Only Hikers actually filters the feed so
/// far (`pods.bedsTotal`); Wifi/Pets/Check-in/Checkout are fully
/// interactive but have no backing data yet (no columns on `pods`, no
/// bookings table), so they're along for the ride until that lands.
/// Replaces the old scrollable Lenny/All-types/category-type filter
/// row entirely.
struct HomeSearchRow: View {
    @Binding var searchText: String

    @FocusState private var isFocused: Bool
    @State private var filtersExpanded = false
    /// Lags behind `isFocused` on purpose — the box grows to its full
    /// height first, then these fade in, instead of both happening at
    /// once.
    @State private var showControls = false
    @ObservedObject private var searchState = HomeSearchState.shared
    @ObservedObject private var lenny = LennySearchViewModel.shared
    @ObservedObject private var filters = HomeFiltersState.shared

    private var isLennyMode: Bool { lenny.phase == .editing }
    /// A Lenny query has been submitted — nothing left to edit, so the
    /// field and pill chrome give way to plain status text.
    private var isLennyBusy: Bool { lenny.phase == .searching || lenny.phase == .results }

    private var textBinding: Binding<String> {
        isLennyMode ? $lenny.itineraryText : $searchText
    }

    private var placeholder: String {
        isLennyMode ? "e.g. Chamonix to Zermatt in 5 days" : "Search by location"
    }

    private var submitDisabled: Bool {
        (isLennyMode ? lenny.itineraryText : searchText).isEmpty
    }

    /// "Lenny speaking : " (bold) + "Your plan is ready !" (medium) —
    /// built with AttributedString since Text's `+` operator is
    /// deprecated (same pattern as ProfilePromoCard.promoTitle).
    private var readyMessage: AttributedString {
        var bold = AttributeContainer()
        bold.font = AppFont.mediumLabel()
        let prefix = AttributedString("Lenny speaking : ", attributes: bold)

        var medium = AttributeContainer()
        medium.font = AppFont.mediumLabel()
        let suffix = AttributedString("Your plan is ready !", attributes: medium)

        return prefix + suffix
    }

    private func submit() {
        // Unfocus right away in both modes — for Lenny this also lets the
        // keyboard's dismiss animation play out during the phase's own
        // transition delay instead of the field just vanishing under it
        // once the pill switches to its busy status text.
        isFocused = false
        if isLennyMode {
            Task { await lenny.submit() }
        }
    }

    /// Filter rows, inline right below the mode-toggle/Filters/submit row
    /// instead of a separate sheet — folds open in place the same way the
    /// pill itself does.
    private var filtersPanel: some View {
        VStack(spacing: 14) {
            FilterRow(title: "Hikers", helper: "Number of hikers with you.") {
                StepperControl(value: $filters.hikers)
            }

            FilterRow(title: "Check-in", helper: "Date of arrival in your pod.") {
                DatePicker("", selection: $filters.checkIn, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.appAccentBlack)
            }

            FilterRow(title: "Checkout", helper: "Date of leaving from your pod.") {
                DatePicker("", selection: $filters.checkOut, in: filters.checkIn..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(.appAccentBlack)
            }

            FilterRow(title: "Wifi", helper: "Location is wired or not.") {
                ToggleCheckButton(isOn: $filters.wifi)
            }

            FilterRow(title: "Pets", helper: "Pets are allowed in the pod or not.") {
                ToggleCheckButton(isOn: $filters.pets)
            }

            PillButton(title: "Save") {
                filtersExpanded = false
            }
        }
        .padding(.top, 4)
        // Plain fade only — `.move(edge: .top)` translated the panel
        // through the controls row above it on the way in/out, which
        // showed as a flash of its content sliding across that row
        // instead of cleanly appearing/disappearing in place. The pill's
        // own height animation already provides the "grow" motion.
        .transition(.opacity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if isLennyMode || isLennyBusy {
                    LennyIcon(size: 14)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.4))
                }

                if isLennyBusy {
                    if lenny.phase == .searching {
                        Text("Lenny is searching...")
                            .font(AppFont.mediumLabel())
                    } else {
                        Text(readyMessage)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        lenny.cancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.appTextMuted)
                    }
                } else {
                    TextField("", text: textBinding, prompt: Text(placeholder).foregroundColor(.black.opacity(0.35)))
                        .font(AppFont.pillLabelMedium(15))
                        .foregroundColor(.black)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($isFocused)
                        .onSubmit { submit() }
                }
            }
            // The icon+placeholder pair reads as sitting slightly
            // left-heavy against the pill's edge — a small nudge balances
            // it. Skipped once Lenny's busy: that row has its own layout
            // (status text + Spacer + cancel button) and doesn't need it.
            .padding(.leading, isLennyBusy ? 0 : 5)

            if isFocused {
                HStack(spacing: 8) {
                    CategoryChip(
                        title: isLennyMode ? "Search" : "Lenny",
                        icon: isLennyMode ? "magnifyingglass" : "lenny"
                    ) {
                        if isLennyMode {
                            lenny.revertToLocationSearch()
                        } else {
                            lenny.activate()
                        }
                    }

                    CategoryChip(title: "Filters", isSelected: filtersExpanded, icon: "slider.horizontal.3") {
                        filtersExpanded.toggle()
                    }

                    Spacer()

                    Button(action: submit) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(submitDisabled ? .black.opacity(0.15) : .appAccentBlack)
                    }
                    .disabled(submitDisabled)
                }
                .opacity(showControls ? 1 : 0)

                if filtersExpanded {
                    filtersPanel
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Same fixed radius in both states (a plain Capsule() would
            // chase height/2 and balloon into an exaggerated stadium
            // shape once expanded) — keeping it constant means only the
            // height animates during the transition, not the radius too.
            if !isLennyBusy {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.appBorder, lineWidth: 0.5)
                    )
            }
        }
        // `.background` doesn't clip — without this, the filters panel's
        // move-from-top transition briefly renders above the pill's
        // rounded edge (and below it on the way back out) instead of
        // sliding cleanly inside it. The shadow has to be applied after
        // this (not inside the background above) or the clip would cut
        // the shadow's blur off too.
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: isLennyBusy ? .clear : .black.opacity(0.08), radius: 3, y: 1)
        .animation(.easeInOut(duration: 0.25), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: isLennyMode)
        .animation(.easeInOut(duration: 0.2), value: isLennyBusy)
        .animation(.easeInOut(duration: 0.25), value: filtersExpanded)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                stops: [.init(color: Color.appHomeBackground.opacity(0.95), location: 0.68),
                        .init(color: Color.appHomeBackground.opacity(0), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .onChange(of: isFocused) { _, focused in
            searchState.isExpanded = focused
            if focused {
                // Let the box finish growing before the controls fade in.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    guard isFocused else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls = true
                    }
                }
            } else {
                showControls = false
                // Losing focus without submitting (scrolling away, tapping
                // outside...) shouldn't strand the pill in Lenny mode —
                // only if there's nothing typed, though; an in-progress
                // draft is worth keeping around for when they come back.
                if isLennyMode && lenny.itineraryText.isEmpty {
                    lenny.revertToLocationSearch()
                }
            }
        }
        .onChange(of: searchState.isExpanded) { _, expanded in
            // Someone outside this view (HomeView's tap-outside-to-dismiss)
            // closed it — mirror that down into the real FocusState that
            // controls the keyboard. We're the one driving `isExpanded`
            // the rest of the time, via the onChange above, so only react
            // when it's telling us to close and we haven't already.
            if !expanded && isFocused {
                isFocused = false
            }
        }
    }
}

/// A single "label + helper text ... control" row, separated by a
/// hairline divider below it. Lives inline in the search pill's Filters
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
                    Text(title)
                        .font(AppFont.itemTitle())
                        .foregroundColor(.appTextPrimary)
                    Text(helper)
                        .font(AppFont.itemHelper())
                        .foregroundColor(.appTextSecondary)
                }
                Spacer()
                control()
            }

            Divider()
                .background(Color.appBorder)
                .padding(.top, 12)
        }
    }
}

/// The small "Lenny" mark (12x12), reused in the chip and the search
/// bar's leading icon. Custom SVG asset if present, else a simple
/// fallback so nothing breaks before it's exported.
struct LennyIcon: View {
    var size: CGFloat = 12

    var body: some View {
        Group {
            if UIImage(named: "lenny") != nil {
                Image("lenny").resizable()
            } else {
                Image(systemName: "sparkles").resizable()
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
    }
}

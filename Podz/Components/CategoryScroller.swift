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
        (isSelected || title == "Lenny") ? AppFont.pillLabel(17) : AppFont.pillLabelMedium(17)
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
                Image(systemName: name)
            }
        }
        .frame(width: 14, height: 14)
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
/// text field would be misleading. Replaces the old scrollable
/// Lenny/All-types/category-type filter row entirely — real filtering
/// logic for the Filters sheet is coming later, this just opens it.
struct HomeSearchRow: View {
    @Binding var searchText: String

    @FocusState private var isFocused: Bool
    @State private var showFilters = false
    /// Lags behind `isFocused` on purpose — the box grows to its full
    /// height first, then these fade in, instead of both happening at
    /// once.
    @State private var showControls = false
    @ObservedObject private var searchState = HomeSearchState.shared
    @ObservedObject private var lenny = LennySearchViewModel.shared

    private var isLennyMode: Bool { lenny.phase == .editing }
    /// A Lenny query has been submitted — nothing left to edit, so the
    /// field and pill chrome give way to plain status text.
    private var isLennyBusy: Bool { lenny.phase == .searching || lenny.phase == .results }

    private var textBinding: Binding<String> {
        isLennyMode ? $lenny.itineraryText : $searchText
    }

    private var placeholder: String {
        isLennyMode ? "Describe your hike itinerary and Lenny will carry on..." : "Search by location"
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

                    CategoryChip(title: "Filters", icon: "slider.horizontal.3") {
                        showFilters = true
                    }

                    Spacer()

                    Button(action: submit) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(submitDisabled ? .black.opacity(0.15) : .appAccentBlack)
                    }
                    .disabled(submitDisabled)
                }
                .opacity(showControls ? 1 : 0)
            }
        }
        .padding(.horizontal, 14)
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
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: isLennyMode)
        .animation(.easeInOut(duration: 0.2), value: isLennyBusy)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                stops: [.init(color: Color.appHomeBackground.opacity(0.95), location: 0.68),
                        .init(color: Color.appHomeBackground.opacity(0), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .sheet(isPresented: $showFilters) {
            FiltersView()
        }
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
            }
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

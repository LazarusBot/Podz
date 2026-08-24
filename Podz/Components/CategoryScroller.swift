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

/// Home's top search field — takes the full row width. Tapping it
/// (focusing the text field) expands the pill to roughly double height,
/// revealing a bottom row: the "Lenny" chip + a "Filters" button on the
/// left, a submit button on the right. Submitting collapses it back
/// down. Replaces the old scrollable Lenny/All-types/category-type
/// filter row entirely — real filtering logic for the Filters sheet is
/// coming later, this just opens it.
struct HomeSearchRow: View {
    @Binding var searchText: String
    var onTapLenny: () -> Void = {}

    @FocusState private var isFocused: Bool
    @State private var showFilters = false
    /// Lags behind `isFocused` on purpose — the box grows to its full
    /// height first, then these fade in, instead of both happening at
    /// once.
    @State private var showControls = false
    @ObservedObject private var searchState = HomeSearchState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.4))
                TextField("", text: $searchText, prompt: Text("Search by location").foregroundColor(.black.opacity(0.35)))
                    .font(AppFont.pillLabelMedium(15))
                    .foregroundColor(.black)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit { isFocused = false }
            }

            if isFocused {
                HStack(spacing: 8) {
                    CategoryChip(title: "Lenny", icon: "lenny") {
                        isFocused = false
                        onTapLenny()
                    }

                    CategoryChip(title: "Filters", icon: "slider.horizontal.3") {
                        showFilters = true
                    }

                    Spacer()

                    Button {
                        isFocused = false
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(searchText.isEmpty ? .black.opacity(0.15) : .appAccentBlack)
                    }
                    .disabled(searchText.isEmpty)
                }
                .opacity(showControls ? 1 : 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // Same fixed radius in both states (a plain Capsule() would
            // chase height/2 and balloon into an exaggerated stadium
            // shape once expanded) — keeping it constant means only the
            // height animates during the transition, not the radius too.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.appBorder, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: isFocused)
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

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

    /// Lenny gets its own accent instead of the plain black/white chip
    /// styling — it's the one chip that launches the AI flow rather than
    /// toggling a filter, so it's worth calling out on sight. Filled
    /// amber (not just an amber outline) so it reads as strongly as the
    /// filled black "selected" state does elsewhere.
    private var isLenny: Bool { title == "Lenny" }

    /// A darkened shade of the gradient's blue, used only for the
    /// shadow — the gradient itself at low opacity read as a pale halo
    /// instead of a grounding drop shadow, same reason the rest of the
    /// app's pills use a dark shadow rather than a tinted-down fill color.
    private var lennyShadowColor: Color {
        Color(red: 0.18, green: 0.35, blue: 0.57).opacity(0.18)
    }

    /// Tint fed to the native Liquid Glass material — same blue as the
    /// old gradient's bottom stop, at reduced opacity so the glass's own
    /// translucency/refraction still shows through rather than reading
    /// as a flat color.
    private var lennyGlassTint: Color {
        Color(red: 0.306, green: 0.580, blue: 0.953).opacity(0.5)
    }

    private var chipLabel: some View {
        HStack(spacing: 8) {
            if let icon {
                ChipIcon(name: icon, isSelected: isSelected || isLenny)
            }

            Text(title)
                .font(labelFont)
                .foregroundColor((isSelected || isLenny) ? .white : .black)

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

    var body: some View {
        if isLenny {
            // Liquid Glass instead of the flat pillStyle background —
            // the whole point is the system material's own translucency/
            // refraction of whatever's behind it, which a solid gradient
            // fill can't give; a plain color .tint() replaces the old
            // white-to-blue gradient as the closest equivalent. Kept as
            // its own branch rather than teaching pillStyle about glass,
            // since every other chip still wants the flat Capsule look.
            Button(action: action) { chipLabel }
                .glassEffect(.regular.tint(lennyGlassTint).interactive(), in: .capsule)
                .shadow(color: lennyShadowColor, radius: 3, y: 1)
        } else {
            Button(action: action) { chipLabel }
                .pillStyle(
                    fill: isSelected ? .appAccentBlack : .white,
                    border: .appBorder
                )
        }
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

/// Reports a measured width up through the view tree — used to capture
/// the Save button's two label states' real rendered widths so its
/// resize can be driven as a plain animated CGFloat. SwiftUI reliably
/// interpolates that; it does not reliably interpolate the width change
/// an HStack undergoes from its content simply changing (tried both
/// content-transition and genuine insert/remove — both snapped the
/// container to its final size instead of growing smoothly).
private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Reports the mode-toggle chip's frame up to HomeView, but only while
/// it's actually reads "Lenny" (classic-search mode) — HomeView uses this
/// to position the first-time coachmark that points at it, and there's
/// nothing to point at once the chip has flipped to "Search".
struct LennyChipAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct HomeSearchRow: View {
    private enum SaveButtonPhase {
        case idle, loading, saved
    }

    @Binding var searchText: String

    @FocusState private var isFocused: Bool
    /// Drives the Save button's Default → loading → "Saved ✓" sequence
    /// (Figma node 3639:865) before the panel collapses — confirms the
    /// tap landed instead of the panel just vanishing.
    @State private var savePhase: SaveButtonPhase = .idle
    /// 0→1 fill fraction for the loading progress bar, animated linearly
    /// over the loading phase's duration — not the same thing as
    /// `savePhase`, which just gates text/checkmark/disabled state.
    @State private var saveProgress: CGFloat = 0
    // Real rendered widths of the button's two label states, captured
    // once via hidden measurement views (see `saveWidthMeasurers`) — and
    // the width actually being displayed, which `saveFilters()` animates
    // between the two as a plain CGFloat.
    @State private var saveIdleWidth: CGFloat = 60
    @State private var saveSavedWidth: CGFloat = 92
    @State private var saveDisplayedWidth: CGFloat = 60
    /// Lags behind `isFocused` on purpose — the box grows to its full
    /// height first, then these fade in, instead of both happening at
    /// once.
    @State private var showControls = false
    /// Set right before `selectSuggestion` blurs the field — picking a
    /// suggestion has nothing left to type, but unlike a normal blur
    /// (tap outside, submit) the pill shouldn't collapse all the way
    /// back to idle over it: the Lenny/Filters/submit row should stay
    /// reachable. Consumed by the isFocused onChange below, same
    /// one-shot-flag pattern as `filters.datePickerActive`.
    @State private var isSelectingSuggestion = false
    /// The value last picked from the suggestions dropdown, if any —
    /// `showSuggestions` stays suppressed as long as `searchText` still
    /// exactly matches it, and un-suppresses itself the moment it
    /// doesn't (typing or deleting even one character), with no explicit
    /// reset needed anywhere.
    @State private var lastSelectedSuggestionValue: String?
    @ObservedObject private var searchState = HomeSearchState.shared
    @ObservedObject private var lenny = LennySearchViewModel.shared
    @ObservedObject private var filters = HomeFiltersState.shared
    @ObservedObject private var podsStore = PodsStore.shared

    private var isLennyMode: Bool { lenny.phase == .editing }
    /// A Lenny query has been submitted — nothing left to edit, so the
    /// field and pill chrome give way to plain status text.
    private var isLennyBusy: Bool { lenny.phase == .searching || lenny.phase == .results }

    private struct LocationSuggestion: Identifiable {
        let value: String   // filled into searchText — matches what HomeView actually filters on
        let label: String   // what's shown in the row
        var id: String { value }
    }

    /// Region/country matches for the typed query, classic-search only —
    /// sourced from already-loaded `PodsStore` data instead of a new
    /// endpoint, and restricted to the same fields (`country`/`region`)
    /// HomeView's own filtering checks, so picking a suggestion is
    /// guaranteed to actually surface results rather than a pod name
    /// that HomeView wouldn't match on.
    private var suggestions: [LocationSuggestion] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !isLennyMode, !isLennyBusy, !query.isEmpty else { return [] }

        var seen = Set<String>()
        var results: [LocationSuggestion] = []

        for pod in podsStore.pods {
            guard results.count < 5 else { break }
            guard let region = pod.region, region.localizedCaseInsensitiveContains(query) else { continue }
            guard seen.insert(region).inserted else { continue }
            results.append(LocationSuggestion(value: region, label: "\(region), \(pod.country)"))
        }

        for country in podsStore.countries {
            guard results.count < 5 else { break }
            guard country.localizedCaseInsensitiveContains(query) else { continue }
            guard seen.insert(country).inserted else { continue }
            results.append(LocationSuggestion(value: country, label: country))
        }

        return results
    }

    private var showSuggestions: Bool {
        isFocused && !filters.isExpanded && !suggestions.isEmpty && searchText != lastSelectedSuggestionValue
    }

    /// Mirrors HomeView's own feed-filtering check — used only to decide
    /// whether refocusing after Filters' Save is safe. With a query
    /// typed and matching pods already showing, refocusing pops the
    /// keyboard back up right as the panel collapses, and that's exactly
    /// the "bump" saveFilters() is avoiding; with nothing showing yet,
    /// there's nothing to reflow and refocusing is back to being the
    /// right call — see saveFilters() below.
    private var hasVisibleFeedResults: Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return false }
        return podsStore.countries.contains { country in
            podsStore.pods(inCountry: country).contains { pod in
                let matchesQuery = country.localizedCaseInsensitiveContains(query)
                    || (pod.region?.localizedCaseInsensitiveContains(query) ?? false)
                let matchesHikers = filters.hikers == 0 || (pod.bedsTotal ?? 0) >= filters.hikers
                return matchesQuery && matchesHikers
            }
        }
    }

    private func selectSuggestion(_ suggestion: LocationSuggestion) {
        searchText = suggestion.value
        lastSelectedSuggestionValue = suggestion.value
        isSelectingSuggestion = true
        isFocused = false
    }

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

    private func saveFilters() {
        let loadingDuration = 0.6
        savePhase = .loading
        withAnimation(.linear(duration: loadingDuration)) {
            saveProgress = 1
        }
        // Let the bar actually finish filling before flipping to
        // "Saved ✓" — otherwise the two blur into one instant jump.
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingDuration) {
            withAnimation(.easeInOut(duration: 0.4)) {
                savePhase = .saved
                saveDisplayedWidth = saveSavedWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                // Back to the expanded pill with the chip row visible,
                // not all the way down to idle — filters was just one
                // stop along the way, not the end of the search.
                // Explicit withAnimation so the collapse itself is one
                // clean motion rather than leaning on the ambient
                // .animation(value: filters.isExpanded) modifier alone.
                withAnimation(.easeInOut(duration: AppMotion.standard)) {
                    filters.isExpanded = false
                }
                savePhase = .idle
                saveProgress = 0
                saveDisplayedWidth = saveIdleWidth
                // Refocusing pops the keyboard back up — fine, even nice
                // (picks typing back up right where they left off), when
                // there's nothing on screen for that to disturb. But
                // with a filtered feed already showing, the keyboard
                // rising at the exact moment the panel collapses is
                // exactly the "bump" of two competing animations landing
                // together, so it's skipped there.
                if !hasVisibleFeedResults {
                    isFocused = true
                }
            }
        }
    }

    /// Invisible, hit-testing-disabled clones of the Save button's two
    /// label states, laid out purely to report their real rendered width
    /// via `WidthPreferenceKey` into `saveIdleWidth`/`saveSavedWidth` —
    /// what `saveFilters()` animates `saveDisplayedWidth` between.
    private var saveWidthMeasurers: some View {
        Group {
            HStack(spacing: 8) {
                Text("Save").font(AppFont.pillLabel(18))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            // Without this, the measurer gets squeezed into whatever
            // size its parent (the button's own already width-
            // constrained .background) proposes, instead of reporting
            // its own true natural size — which is exactly why the
            // checkmark's box (`saveSavedWidth`) kept coming back
            // roughly equal to the idle width and never actually grew.
            .fixedSize()
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(WidthPreferenceKey.self) { width in
                saveIdleWidth = width
                if savePhase == .idle { saveDisplayedWidth = width }
            }

            HStack(spacing: 8) {
                Text("Saved").font(AppFont.pillLabel(18))
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .fixedSize()
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(WidthPreferenceKey.self) { saveSavedWidth = $0 }
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Filter rows, inline right below the mode-toggle/Filters/submit row
    /// instead of a separate sheet — folds open in place the same way the
    /// pill itself does.
    private var filtersPanel: some View {
        // .leading, not the default .center — the Save button is the
        // only child here that doesn't already stretch full width
        // (every FilterRow does, via its own internal Spacer), so this
        // only affects it. Centered, its resize grew both edges outward
        // from the middle at once — width animating smoothly plus the
        // whole button re-centering every frame reads as a jump, not a
        // clean grow. Leading-anchored, only the trailing edge moves.
        VStack(alignment: .leading, spacing: 14) {
            FilterRow(title: "Hikers", helper: "Number of hikers with you.") {
                StepperControl(value: $filters.hikers, label: "hikers")
            }

            FilterRow(title: "Check-in", helper: "Date of arrival in your pod.") {
                HStack(spacing: 8) {
                    DatePicker("", selection: $filters.checkIn, displayedComponents: .date)
                        .labelsHidden()
                        .tint(.appAccentBlack)
                        // .simultaneousGesture never fired here — compact
                        // DatePicker is UIKit-backed internally, and its
                        // own touch handling swallows the tap before
                        // SwiftUI's gesture recognizer sees it. The date
                        // actually changing is a reliable SwiftUI-level
                        // signal instead.
                        .onChange(of: filters.checkIn) { _, _ in
                            filters.datePickerActive = true
                        }
                    DateConfirmButton(hasChanged: filters.checkIn != filters.initialCheckIn) {
                        filters.initialCheckIn = filters.checkIn
                        filters.datePickerActive = false
                    }
                }
            }

            FilterRow(title: "Checkout", helper: "Date of leaving from your pod.") {
                HStack(spacing: 8) {
                    DatePicker("", selection: $filters.checkOut, in: filters.checkIn..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(.appAccentBlack)
                        .onChange(of: filters.checkOut) { _, _ in
                            filters.datePickerActive = true
                        }
                    DateConfirmButton(hasChanged: filters.checkOut != filters.initialCheckOut) {
                        filters.initialCheckOut = filters.checkOut
                        filters.datePickerActive = false
                    }
                }
            }

            FilterRow(title: "Wifi", helper: "Location is wired or not.") {
                ToggleCheckButton(isOn: $filters.wifi, label: "Wifi")
            }

            FilterRow(title: "Pets", helper: "Pets are allowed in the pod or not.") {
                ToggleCheckButton(isOn: $filters.pets, label: "Pets")
            }

            // Custom rather than PillButton — needs the Default → loading
            // → Saved(✓) sequence from Figma node 3639:865, and sized to
            // match the Search/Filters chips (PillButton's own sizing is
            // smaller) since it's another pill in the same search bar.
            //
            // The resize itself is driven as a plain animated CGFloat
            // (`saveDisplayedWidth`), not left to implicit layout — every
            // other approach tried here (a single Text's content
            // changing, .contentTransition, genuine .id()-driven
            // insert/remove) had the container's width snap to its final
            // size instead of interpolating, with only the label's
            // opacity actually animating smoothly around that jump.
            // Explicit frame(width:) changes are what SwiftUI reliably
            // tweens, so `saveWidthMeasurers` below captures the two
            // states' real widths once, and saveFilters() animates
            // between them directly.
            Button(action: saveFilters) {
                ZStack(alignment: .leading) {
                    HStack(spacing: 8) {
                        Text("Save")
                            .font(AppFont.pillLabel(18))
                            .foregroundColor(.black)
                    }
                    .fixedSize()
                    .opacity(savePhase == .saved ? 0 : 1)

                    HStack(spacing: 8) {
                        Text("Saved")
                            .font(AppFont.pillLabel(18))
                            .foregroundColor(.black)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .fixedSize()
                    .opacity(savePhase == .saved ? 1 : 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(width: saveDisplayedWidth, alignment: .leading)
                .clipped()
                .background {
                    // GeometryReader only while actually loading — it's
                    // what the progress-bar sweep needs to track the
                    // label's width, but leaving a GeometryReader sitting
                    // in the tree recomputes from the *current* real
                    // layout size every frame instead of interpolating,
                    // which is exactly the kind of thing that was
                    // fighting smooth resizing elsewhere here. Once
                    // loading's done there's nothing left to track (it's
                    // already a full, static fill), so a plain Capsule
                    // for that part doesn't have the issue.
                    switch savePhase {
                    case .loading:
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.appBorder.opacity(0.5))
                                .frame(width: geo.size.width * saveProgress)
                        }
                        .clipShape(Capsule())
                    case .saved:
                        Capsule().fill(Color.appBorder.opacity(0.5))
                    case .idle:
                        EmptyView()
                    }
                }
            }
            .disabled(savePhase != .idle)
            .pillStyle()
            .background(saveWidthMeasurers)
        }
        // 18, not 4 — keeps Hikers the same distance from the chip row
        // above that the removed leading DashedDivider used to give it
        // (its own 1pt height plus the VStack's 14pt inter-row spacing),
        // so the panel still reads as breathable instead of Hikers
        // crowding straight up against the pills.
        .padding(.top, 18)
        // Plain fade only — `.move(edge: .top)` translated the panel
        // through the controls row above it on the way in/out, which
        // showed as a flash of its content sliding across that row
        // instead of cleanly appearing/disappearing in place. The pill's
        // own height animation already provides the "grow" motion.
        .transition(.opacity)
    }

    /// Location suggestions for the classic search tab, folded open the
    /// same way `filtersPanel` is — right below the mode-toggle row,
    /// once typing has actually started (`suggestions` is empty for a
    /// blank query, so this never shows on a bare focus). Lenny mode has
    /// no equivalent: itinerary text isn't a single place name, so
    /// autocompleting it against country/region strings wouldn't mean
    /// anything.
    private var suggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            DashedDivider()
                .padding(.bottom, 10)

            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    selectSuggestion(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appTextMuted)
                        Text(suggestion.label)
                            .font(AppFont.pillLabelMedium(15))
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                    }
                }

                if index < suggestions.count - 1 {
                    DashedDivider()
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(.top, 4)
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
                    .accessibilityLabel("Cancel search")
                } else {
                    TextField("", text: textBinding, prompt: Text(placeholder).foregroundColor(.black.opacity(0.35)))
                        .font(AppFont.pillLabelMedium(17))
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

            // searchState.isExpanded, not isFocused directly — dismissing
            // the keyboard while filters are open (see the onChange
            // below) blurs the field, and gating on isFocused itself
            // would've collapsed this row right along with it. isExpanded
            // is the one thing that's actually true for "the pill should
            // look expanded" regardless of whether the text field
            // currently has keyboard focus.
            if searchState.isExpanded {
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
                    .anchorPreference(key: LennyChipAnchorKey.self, value: .bounds) {
                        isLennyMode ? nil : $0
                    }

                    CategoryChip(title: "Filters", isSelected: filters.isExpanded, icon: "slider.horizontal.3") {
                        filters.isExpanded.toggle()
                    }

                    Spacer()

                    Button(action: submit) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(submitDisabled ? .appBorder.opacity(0.5) : .appAccentBlack)
                    }
                    .disabled(submitDisabled)
                    .accessibilityLabel("Search")
                }
                .opacity(showControls ? 1 : 0)

                if filters.isExpanded {
                    filtersPanel
                } else if showSuggestions {
                    suggestionsPanel
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
                RoundedRectangle(cornerRadius: AppRadius.r24, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.r24, style: .continuous)
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
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.r24, style: .continuous))
        .shadow(color: isLennyBusy ? .clear : .black.opacity(0.08), radius: 3, y: 1)
        // Dead space inside the pill (a FilterRow's label, the gap
        // between it and its control, a DashedDivider...) has no
        // gesture of its own, so without this the tap fell through to
        // HomeView's tap-outside-to-dismiss catcher on the ScrollView
        // and closed the whole panel — tapping *inside* the pill
        // shouldn't dismiss anything, only genuinely outside it.
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.r24, style: .continuous))
        .onTapGesture {}
        .animation(.easeInOut(duration: AppMotion.standard), value: isFocused)
        .animation(.easeInOut(duration: AppMotion.quick), value: isLennyMode)
        .animation(.easeInOut(duration: AppMotion.quick), value: isLennyBusy)
        .animation(.easeInOut(duration: AppMotion.standard), value: filters.isExpanded)
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
            if focused {
                searchState.isExpanded = true
                // Tapping back into the field while filters are open
                // means picking search back up, not filters — drop back
                // to the plain two-row layout (field + chip row) instead
                // of leaving the filters panel sitting open underneath.
                filters.isExpanded = false
                // Let the box finish growing before the controls fade in.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    guard isFocused else { return }
                    withAnimation(.easeInOut(duration: AppMotion.snappy)) {
                        showControls = true
                    }
                }
            } else if isSelectingSuggestion {
                // Picking a suggestion blurs the field (nothing left to
                // type) but shouldn't collapse the pill like a real blur
                // does — the suggestions list closes on its own
                // (showSuggestions already requires isFocused), while
                // searchState.isExpanded/showControls are left as they
                // were so the Lenny/Filters/submit row stays visible and
                // tappable instead of the whole pill dropping back to idle.
                isSelectingSuggestion = false
            } else if !filters.isExpanded {
                // Losing focus while filters are open is deliberate — we
                // dismiss the keyboard ourselves (see the filters.isExpanded
                // onChange below) so it doesn't float over the filter
                // controls, but the pill should stay expanded rather than
                // collapse just because the text field isn't focused
                // anymore. Everything below only applies to a "real"
                // blur (submitting, tapping outside, scrolling away).
                searchState.isExpanded = false
                showControls = false
                // Losing focus without submitting shouldn't strand the
                // pill in Lenny mode — only if there's nothing typed,
                // though; an in-progress draft is worth keeping around
                // for when they come back.
                if isLennyMode && lenny.itineraryText.isEmpty {
                    lenny.revertToLocationSearch()
                }
            }
        }
        .onChange(of: searchState.isExpanded) { _, expanded in
            // Someone outside this view (HomeView's tap-outside-to-dismiss)
            // closed it — mirror that down into our own state. We're the
            // one driving `isExpanded` the rest of the time (via the
            // isFocused onChange above), so only react when it's telling
            // us to close. Filters needs closing here too, not just
            // isFocused — once the panel's open, isFocused is already
            // false (we blur it deliberately), so the guard this used to
            // have (`&& isFocused`) would've skipped this entirely and
            // left tap-outside unable to close an open filters panel.
            guard !expanded else { return }
            isFocused = false
            filters.isExpanded = false
        }
        .onChange(of: filters.isExpanded) { _, expanded in
            // Filter rows are steppers/date pickers/toggles, not text
            // entry — nothing left to type once they're open, so drop
            // the keyboard if the search field was still focused.
            if expanded {
                isFocused = false
            }
        }
    }
}

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

/// Sits next to a Check-in/Checkout DatePicker as an explicit "confirm
/// and close" target. It doesn't control the DatePicker directly —
/// there's no public API for that on its native compact-style overlay —
/// but that overlay already dismisses on any tap outside itself, so
/// this button's only job is to be an obvious place to make that tap
/// instead of leaving people to guess they can tap elsewhere. Grayed
/// out and disabled until the date's actually been changed from where
/// it started — nothing to confirm otherwise. Tapping it (besides the
/// dismiss-by-tapping-outside-the-picker side effect) moves the "start"
/// baseline up to the now-confirmed value, so it grays back out again
/// rather than staying enabled forever after the first change.
private struct DateConfirmButton: View {
    let hasChanged: Bool
    var onConfirm: () -> Void = {}

    var body: some View {
        Button(action: onConfirm) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(hasChanged ? Color.appAccentBlack : Color.appBorder))
        }
        // The visible circle stays 28pt (matches the DatePicker beside
        // it), but the tap target grows to Apple's 44pt HIG minimum —
        // this sits right next to a native DatePicker people are
        // actively fat-fingering, so a target this size was an easy miss.
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Confirm date")
        .disabled(!hasChanged)
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
/// bar's leading icon. Custom SVG asset if present, else a simple
/// fallback so nothing breaks before it's exported.
struct LennyIcon: View {
    var size: CGFloat = 12

    var body: some View {
        Group {
            if UIImage(named: "lenny") != nil {
                Image("lenny").resizable().renderingMode(.template)
            } else {
                Image(systemName: "sparkles").resizable()
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
        .foregroundStyle(Color.appLennyAccent)
    }
}

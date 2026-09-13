import SwiftUI

/// The floating "Switch to X mode ?" confirmation revealed by a long
/// press on either tab bar's Profile tab. One shared view (used by both
/// `BottomTabBar` and `HostTabBar`) rather than each bar growing its own
/// copy — the two bars already duplicate their tab-selection styling once;
/// this mechanic doesn't need a second duplicate on top of that.
///
/// Styled after `PodDetailView`'s `reservationBar` — same dark glass
/// tint/border on the container, same `pillStyle` "volume" treatment
/// (inset highlight + warm-gray shadow) on the black button — rather
/// than the two floating dark bars in this app looking like two
/// different components that happen to both be dark. Own outer margin
/// (12/8, not reservationBar's 16/9) and own handle sizing since, so no
/// longer an exact height match to that bar.
///
/// Committed by dragging the black handle from left to right past
/// `commitThreshold`, or by a plain tap on the handle — the tap fallback
/// matters for VoiceOver/Switch Control, which can't perform the drag.
struct ModeSwitchPill: View {
    let label: String
    @Binding var progress: CGFloat
    let onCommit: () -> Void
    /// Called for a tap anywhere outside the pill while it's up (see
    /// `ModeSwitchDismissCatcher`) as well as for a below-threshold drag
    /// release — both read as "changed their mind."
    var onCancel: () -> Void = {}

    /// The handle's own width is content-driven now (icon + explicit
    /// padding, like `reservationBar`'s Reserve button), not a fixed
    /// `.frame(width:)` — so this is measured, not a constant. 72 is
    /// just a reasonable first-frame guess before the real
    /// `onGeometryChange` measurement lands, avoiding a visible jump.
    @State private var handleWidth: CGFloat = 72
    private let commitThreshold: CGFloat = 0.7
    /// Fixed gap between the handle's resting position and the label —
    /// the label sits at `handleWidth + labelLeadingGap` from the left
    /// edge, not centered across the whole pill, so it reads as "next to
    /// the handle" rather than floating independently in the bar. 25,
    /// matching Figma node 4418:1395's own `gap-[25px]` exactly.
    private let labelLeadingGap: CGFloat = 25
    @State private var trackWidth: CGFloat = 0

    /// How much of the label, measured from its own left edge, the
    /// handle has already swept over (or is currently over) — the label
    /// itself sits still (see `.offset` below); the handle is what
    /// moves, so this is what actually drives which of its letters are
    /// still meant to be visible. Explicitly masked out in
    /// `MetalSweepText` rather than left to the handle's own opacity/
    /// z-order to hide by simply drawing on top — that looked right at
    /// rest but let letters show through once the handle was actually
    /// mid-slide over them.
    private var labelHiddenWidth: CGFloat {
        guard trackWidth > handleWidth else { return 0 }
        let handleRightEdge = progress * (trackWidth - handleWidth) + handleWidth
        let labelLeftEdge = handleWidth + labelLeadingGap
        return max(0, handleRightEdge - labelLeftEdge)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            MetalSweepText(label: label, hiddenWidth: labelHiddenWidth)
                .offset(x: handleWidth + labelLeadingGap)

            Image(systemName: "chevron.right")
                // Sized down from 16 — the glyph itself, not the
                // surrounding `.frame`/padding below, so the pill's own
                // outer size (frame + padding, not the font) is
                // unaffected — just a smaller arrow centered in the
                // same-size button.
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                // Icon frame + padding matched to Figma node 4418:1395's
                // own "Next Button" measurements exactly: a 16x16 icon
                // container, `pl-[24px] pr-[20px] py-[12px]` (asymmetric
                // leading/trailing, not the symmetric 18/18/8 this used
                // to be).
                .frame(width: 16, height: 16)
                .padding(.leading, 24)
                .padding(.trailing, 20)
                .padding(.vertical, 12)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { handleWidth = $0 }
                .pillStyle(
                    fill: Color.appAccentBlack,
                    border: .appBorder,
                    shadow: Color(red: 200 / 255, green: 200 / 255, blue: 200 / 255).opacity(0.1)
                )
                // Same stronger inset sheen `reservationBar`'s Reserve
                // button layers on top of `pillStyle`'s own (fainter)
                // default highlight — see that button's own comment.
                .overlay(
                    Capsule()
                        .stroke(Color(red: 230 / 255, green: 230 / 255, blue: 230 / 255).opacity(0.5), lineWidth: 2)
                        .blur(radius: 3)
                        .offset(y: -2)
                        .mask(Capsule())
                )
                .offset(x: progress * (trackWidth - handleWidth))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let raw = value.translation.width / max(trackWidth - handleWidth, 1)
                            let newProgress = min(max(raw, 0), 1)
                            // A tick right as the drag crosses into "would
                            // commit if released now" — and a lighter one
                            // crossing back out, so scrubbing near the
                            // line stays legible both directions instead
                            // of only announcing the one-time entry.
                            if newProgress >= commitThreshold && progress < commitThreshold {
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            } else if newProgress < commitThreshold && progress >= commitThreshold {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            progress = newProgress
                        }
                        .onEnded { _ in
                            if progress >= commitThreshold {
                                onCommit()
                            } else {
                                // Below threshold reads as "changed their
                                // mind" — closes outright rather than
                                // staying open for a second attempt.
                                onCancel()
                            }
                        }
                )
                .onTapGesture { onCommit() }
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onCommit() }
        }
        // Claims the full available width itself now — the label used
        // to be what stretched the ZStack out (`.frame(maxWidth:
        // .infinity)` on it directly), but it's a fixed-offset, natural-
        // width view now instead of a centered, greedy one, so something
        // else needs to hold the ZStack open to the pill's actual width.
        .frame(maxWidth: .infinity, alignment: .leading)
        // Measures the ZStack's OWN width — before `.padding` below
        // wraps it — since that's the coordinate space the handle's
        // `.offset(x: progress * (trackWidth - handleWidth))` is
        // actually computed in. Measuring the padded/outer width instead
        // (as this used to) meant the handle's own travel range ran 16pt
        // past the ZStack's real right edge at `progress == 1` — visible
        // as the handle poking out past the pill's own glass edge at a
        // full drag, since the ZStack doesn't clip its children.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
        // 12 leading/trailing, 8 vertical — this pill's own outer
        // margin between its glass edge and its inner content (label +
        // handle). No longer matched to `reservationBarContent`'s 16/9
        // — shrinking it leaves more inner width for `trackWidth`
        // (measured above, before this padding), which is what actually
        // gives the handle more room to size/slide into.
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .modifier(ReservationBarGlass())
        // No catch-all `.onTapGesture` here to "protect" the label area
        // from `ModeSwitchDismissCatcher` behind it — stacking a second
        // tap gesture on this container risked swallowing the handle's
        // own drag/tap gesture nested inside it (a real SwiftUI gotcha:
        // overlapping gesture recognizers on a parent vs. child aren't
        // guaranteed to let the child win), which is what silently broke
        // the handle entirely. A tap on the label now falls through and
        // dismisses same as tapping outside — a minor behavior, not a
        // bug, and worth it for the handle actually working again.
    }
}

/// The label's brushed-metal look: a gradient text layer underneath,
/// with a brighter band sweeping left to right on a loop layered on top
/// as the actual "metal" sheen. Figma's own spec (node 4418:1395) is a
/// flat `from-white to-[#999]`, but that washes out in light mode —
/// this pill's glass (`ReservationBarGlass`) is light, near-white, not
/// the dark backdrop the spec was mocked up against — so the base
/// gradient uses `.appTextPrimary` (black light / white dark) instead
/// of a hardcoded `.white`, matching the glass's own light/dark swing
/// rather than reading correctly in only one of the two.
///
/// Plain SwiftUI (`.mask`/`LinearGradient`/a repeating `withAnimation`),
/// not an actual Metal shader — this app has no existing shader
/// pipeline, and the requested look ("metal style") is achievable with
/// a masked gradient sweep at a fraction of the moving parts a real
/// `.colorEffect`/`ShaderLibrary` setup would need.
private struct MetalSweepText: View {
    let label: String
    /// How much of the label's own width, from its left edge, to mask
    /// away — see `ModeSwitchPill.labelHiddenWidth`. Applied here, after
    /// the sweep overlay, so it hides that layer too, not just the base
    /// gradient text underneath it.
    let hiddenWidth: CGFloat
    /// Drives the sweep via a plain repeating animation rather than a
    /// per-frame `TimelineView` — this is a decorative loop, not
    /// something that needs to react to any other state, so the
    /// cheaper implicit-animation approach is enough.
    @State private var sweepForward = false

    private var font: Font { AppFont.mediumLabel(16) }

    var body: some View {
        Text(label)
            .font(font)
            .foregroundStyle(
                LinearGradient(colors: [.appTextPrimary, .appTextMuted], startPoint: .leading, endPoint: .trailing)
            )
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    // Bright band roughly a third of the label's own
                    // width, translated from well off the leading edge
                    // to well past the trailing one so it fully clears
                    // before looping, instead of visibly snapping back.
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.95), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: width * 0.4)
                    .offset(x: sweepForward ? width * 1.2 : -width * 0.6)
                }
                .mask(
                    Text(label).font(font)
                )
            }
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    sweepForward = true
                }
            }
            // Reveals only what's still ahead of the handle — everything
            // from the label's own left edge up to `hiddenWidth` is cut
            // away outright (not faded), so nothing is ever visible
            // under or behind the handle as it slides across.
            .mask(
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        Color.clear.frame(width: min(hiddenWidth, proxy.size.width))
                        Color.black.frame(width: max(proxy.size.width - hiddenWidth, 0))
                    }
                }
            )
    }
}

/// A generously oversized, effectively invisible tap target placed
/// behind `ModeSwitchPill` while it's revealed — this is what makes "tap
/// anywhere outside the bar to dismiss" work from inside `BottomTabBar`/
/// `HostTabBar`, neither of which otherwise has any reach beyond its own
/// small floating-capsule frame. `.overlay` doesn't clip its content to
/// the base view's bounds, so a view this size still renders (and hit-
/// tests) far past the tab bar's own footprint in every direction
/// without disturbing that footprint's own layout.
struct ModeSwitchDismissCatcher: View {
    let onDismiss: () -> Void

    var body: some View {
        Color.black.opacity(0.0001)
            .frame(width: 2000, height: 2000)
            .contentShape(Rectangle())
            // No `withAnimation` here on purpose — a tap genuinely
            // outside the pill should close it immediately, not play the
            // same spring/fade `dismissModeSwitch` uses for a below-
            // threshold drag release. The caller is expected to pass a
            // plain, unanimated state change (see `BottomTabBar`'s and
            // `HostTabBar`'s own `dismissModeSwitchInstantly`).
            .onTapGesture(perform: onDismiss)
    }
}

/// `reservationBar`'s own glass treatment (`.black.opacity(0.1)` tint,
/// `.appBorder` hairline), copied here rather than shared as a modifier
/// across both files — `PodDetailView`'s version also grows into a
/// `RoundedRectangle` for its expanded form panel, which this pill has
/// no equivalent of, so a plain `Capsule()`-only copy is simpler than
/// generalizing that shape-morphing behavior for a caller that doesn't
/// need it.
private struct ReservationBarGlass: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *) {
                content.glassEffect(.regular.tint(.black.opacity(0.1)), in: .capsule)
            } else {
                content.background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().fill(Color.black.opacity(0.1)))
                )
            }
        }
        .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 0.5))
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.gray.ignoresSafeArea()
        ModeSwitchPill(label: "Switch to hosting mode ?", progress: .constant(0.3), onCommit: {})
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
    }
}

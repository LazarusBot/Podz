import SwiftUI

/// Three dots passing a bounce along: Lenny's "one moment", used wherever a
/// system spinner would be (a request in flight, a photo uploading) and as
/// the typing dots of `LennyReply`.
struct LennyDots: View {
    var color: Color = .homeText
    var size: CGFloat = 7

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: size * 0.7) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = reduceMotion ? 0.6 : max(0, sin(time * 7 - Double(index) * 0.9))
                    Circle()
                        .fill(color.opacity(0.3 + 0.5 * wave))
                        .frame(width: size, height: size)
                        .offset(y: -size * 3 / 7 * wave)
                }
            }
        }
        .accessibilityLabel(tr("Loading"))
    }
}

/// Where Lenny's note or question sits on a page: just above the pill row, in
/// the same place as his other bubbles (`abovePills`), or just above the
/// bottom of a page that has no pills (`false`). `respectsSafeArea` is the
/// page's own flag: a sheet or a cover respects the bottom safe area, a tab's
/// content doesn't.
private func lennyBottom(abovePills: Bool, respectsSafeArea: Bool) -> CGFloat {
    let edge = DetailLayout.controlStackGap + (respectsSafeArea ? 0 : ScreenInsets.bottom)
    return abovePills ? edge + 83 + 20 : edge
}

private struct LennyNoteModifier: ViewModifier {
    @Binding var message: String?
    /// Said before the message: "I couldn't send that request. <the reason>".
    var prefix: String?
    var mood: LennyMood
    var abovePills: Bool
    var respectsSafeArea: Bool

    private var shown: String? {
        guard let message else { return nil }
        return prefix.map { "\($0) \(message)" } ?? message
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let shown {
                    // A tap puts it away; otherwise it leaves on its own.
                    Button { message = nil } label: {
                        LennyReply(message: shown, mood: mood)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, lennyBottom(abovePills: abovePills, respectsSafeArea: respectsSafeArea))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: shown) {
                        try? await Task.sleep(for: .seconds(6))
                        if !Task.isCancelled { message = nil }
                    }
                }
            }
            .animation(.smooth(duration: 0.35), value: message)
    }
}

private struct LennyAsksModifier: ViewModifier {
    @Binding var isPresented: Bool
    let question: String
    let confirm: String
    let keep: String
    let isDestructive: Bool
    var abovePills: Bool
    var respectsSafeArea: Bool
    var bottom: CGFloat?
    let onConfirm: () -> Void
    var onKeep: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack(alignment: .bottom) {
                        // The page steps back; a tap on it keeps things as they were.
                        Color.homeBackground.opacity(0.85)
                            .ignoresSafeArea()
                            .onTapGesture { keepThings() }

                        VStack(alignment: .leading, spacing: 4) {
                            LennyReply(message: question, mood: .idle)
                            HStack(spacing: 22) {
                                caption(confirm, color: isDestructive ? .appBadgeRed : .homeText) {
                                    isPresented = false
                                    onConfirm()
                                }
                                caption(keep, color: .homeSubtitle) { keepThings() }
                            }
                            // Lined up with the bubble's text, past the avatar.
                            .padding(.leading, 38 + 18)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, bottom ?? lennyBottom(abovePills: abovePills, respectsSafeArea: respectsSafeArea))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.3), value: isPresented)
    }

    /// "Keep it": the question goes away and things stay as they were.
    private func keepThings() {
        isPresented = false
        onKeep?()
    }

    private func caption(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            T(title)
                .font(AppFont.regularLabel(13))
                .foregroundColor(color)
                .underline(color: color.opacity(0.5))
                .padding(.vertical, 8)
                .captionTapArea()
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// Lenny says it in his bubble instead of a system alert: an error (the red
    /// bubble, `prefix` first in his voice) or a small piece of news (pass
    /// `.happy`). It clears the binding by itself after a few seconds or on a tap.
    func lennyNote(
        _ message: Binding<String?>,
        prefix: String? = nil,
        mood: LennyMood = .sorry,
        abovePills: Bool = true,
        respectsSafeArea: Bool = false
    ) -> some View {
        modifier(LennyNoteModifier(message: message, prefix: prefix, mood: mood, abovePills: abovePills, respectsSafeArea: respectsSafeArea))
    }

    /// Lenny asks before something that can't be undone, in his bubble, with
    /// the two answers as captions under it (the destructive one in red),
    /// instead of a system alert.
    func lennyAsks(
        isPresented: Binding<Bool>,
        question: String,
        confirm: String,
        keep: String = "Cancel",
        isDestructive: Bool = true,
        abovePills: Bool = true,
        respectsSafeArea: Bool = false,
        bottom: CGFloat? = nil,
        onKeep: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(LennyAsksModifier(
            isPresented: isPresented, question: question, confirm: confirm, keep: keep,
            isDestructive: isDestructive, abovePills: abovePills, respectsSafeArea: respectsSafeArea,
            bottom: bottom, onConfirm: onConfirm, onKeep: onKeep
        ))
    }
}

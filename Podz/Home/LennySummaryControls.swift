import SwiftUI

/// List or Map: the two ways to look at a plan, a small capsule in the pill
/// grey with the chosen side inverted (ground and ink swapped, like the small
/// action pills).
struct PlanModeToggle: View {
    @Binding var showsMap: Bool

    var body: some View {
        HStack(spacing: 0) {
            side("List", isOn: !showsMap) { showsMap = false }
            side("Map", isOn: showsMap) { showsMap = true }
        }
        .padding(3)
        .background(Color.homePill, in: Capsule())
        .animation(.smooth(duration: 0.25), value: showsMap)
    }

    private func side(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            T(title)
                .font(AppFont.regularLabel(13))
                .foregroundColor(isOn ? .homeBackground : .homeText)
                .padding(.horizontal, 16)
                .frame(height: 30)
                .background(isOn ? Color.homeText : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// "Save plan" keeps the plan in Profile > Plans without booking; once saved
/// it reads "Saved" and a tap takes it back out.
struct SavePlanCaption: View {
    let isSaved: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 12, weight: .regular))
                T(isSaved ? "Saved" : "Save plan")
                    .font(AppFont.regularLabel(13))
            }
            .foregroundColor(isSaved ? .homeText : .homeSubtitle)
            .padding(.vertical, 8)
            .captionTapArea()
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: isSaved) { _, saved in saved }
        .accessibilityLabel(tr(isSaved ? "Saved. Tap to remove" : "Save plan"))
    }
}

/// The round pill in the control stack that gets out of the whole plan flow
/// in one tap (the back pill only steps back): a thin cross like the back
/// pill's chevron, at 35%.
struct DetailCloseButton: View {
    var action: () -> Void

    var body: some View {
        DetailRoundButton(accessibilityLabel: tr("Leave the plan"), action: action) {
            CrossGlyph()
                .stroke(Color.homeText.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 12, height: 12)
        }
    }
}

private struct CrossGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

extension View {
    /// Lenny asks before a plan that isn't saved is left behind.
    func lennyAsksToLeave(_ isPresented: Binding<Bool>, onLeave: @escaping () -> Void) -> some View {
        lennyAsks(
            isPresented: isPresented,
            question: "Leave this plan? It isn't saved yet.",
            confirm: "Leave",
            keep: "Stay",
            isDestructive: false,
            respectsSafeArea: true,
            onConfirm: onLeave
        )
    }
}

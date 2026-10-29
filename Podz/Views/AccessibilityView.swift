import SwiftUI

/// Reached by tapping "Accessibility" on ProfileView. Podz doesn't have its
/// own accessibility preferences (no in-app Reduce Motion switch, etc.) — it
/// follows whatever iOS is already set to (Dynamic Type, VoiceOver, Reduce
/// Motion all work through standard SwiftUI controls without extra wiring).
/// Rather than fake toggles that wouldn't do anything, this screen says so
/// and offers to open where those settings actually live.
struct AccessibilityView: View {
    var onBack: () -> Void

    var body: some View {
        SectionPage(
            title: "Accessibility",
            onBack: onBack,
            trailing: {
                DetailTextButton(title: "Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        ) {
            Text("Podz follows your iOS accessibility settings, including VoiceOver, Dynamic Type, and Reduce Motion. There's nothing to configure here — manage them in Settings.")
                .font(AppFont.regularLabel(16))
                .lineSpacing(5)
                .foregroundColor(.homeBodyText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
    }
}

#Preview {
    AccessibilityView(onBack: {})
}

import SwiftUI

/// Reached by tapping "Accessibility" on ProfileView. Podz doesn't have
/// its own accessibility preferences (no in-app Reduce Motion switch,
/// etc.) — it follows whatever iOS is already set to (Dynamic Type,
/// VoiceOver, Reduce Motion all work through standard SwiftUI controls
/// without extra wiring). Rather than fake toggles that wouldn't do
/// anything, this screen says so and links out to where those settings
/// actually live.
struct AccessibilityView: View {
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProfileTopBar(title: "Accessibility", onBack: onBack)

            Text("Podz follows your iOS accessibility settings, including VoiceOver, Dynamic Type, and Reduce Motion. There's nothing to configure here — manage them in Settings.")
                .font(.system(size: 14))
                .foregroundColor(.appTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

            ProfileMenuRow(icon: "gearshape", title: "Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }

            Spacer()
        }
        .background(Color.appHomeBackground)
    }
}

#Preview {
    AccessibilityView(onBack: {})
}

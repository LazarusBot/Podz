import SwiftUI

/// The whole minimalist onboarding, welcome → region. The first three
/// steps sign the user in (email code); the last three are an intro for
/// brand-new accounts only. A returning user never reaches those — the
/// session landing swaps the root view to the app (see `OnboardingView`).
struct OnboardingFlow: View {
    enum Step {
        case welcome, email, code, find, lenny, region
    }

    @StateObject private var auth = AuthManager.shared
    @State private var step: Step = .welcome
    @State private var email = ""

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                OnboardingWelcomeStep(onStart: { go(.email) })
                    .transition(.opacity)
            case .email:
                OnboardingEmailStep(email: $email, onCodeSent: { go(.code) })
                    .transition(.opacity)
            case .code:
                OnboardingCodeStep(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    onChangeEmail: { go(.email) },
                    onNewAccount: { go(.find) }
                )
                .transition(.opacity)
            case .find:
                OnboardingFindStep(onContinue: { go(.lenny) })
                    .transition(.opacity)
            case .lenny:
                OnboardingLennyStep(onBack: { go(.find) }, onContinue: { go(.region) })
                    .transition(.opacity)
            case .region:
                OnboardingRegionStep(onBack: { go(.lenny) }, onFinish: finish)
                    .transition(.opacity)
            }
        }
        .background(Color.onbBackground.ignoresSafeArea())
    }

    private func go(_ next: Step) {
        withAnimation(.easeInOut(duration: AppMotion.standard)) { step = next }
    }

    private func finish(with region: OnboardingRegion) {
        UserDefaults.standard.set(region.rawValue, forKey: OnboardingRegion.storageKey)
        auth.finishPostRegisterOnboarding()
    }
}

import SwiftUI

/// Step 4 — "Find the perfect pod". `canGoBack` is false here: the step
/// before it is the code, and the account already exists by now.
struct OnboardingFindStep: View {
    var onContinue: () -> Void

    var body: some View {
        OnboardingHeroScreen(
            photo: "ObPod",
            title: "Find the perfect pod",
            subtitle: "Discover unique, architectural stays and cozy cabins hidden deep within nature's most stunning landscapes."
        ) {
            OnboardingActionRow(canGoBack: false, onBack: {}, onContinue: onContinue)
        }
    }
}

/// Step 5 — "Meet Lenny".
struct OnboardingLennyStep: View {
    var onBack: () -> Void
    var onContinue: () -> Void

    var body: some View {
        OnboardingHeroScreen(
            photo: "ObDeck",
            title: "Meet Lenny",
            subtitle: "Tell him where and when. He finds you a bed in a mountain pod.",
            showsLennyBadge: true
        ) {
            OnboardingActionRow(onBack: onBack, onContinue: onContinue)
        }
    }
}

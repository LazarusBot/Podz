import SwiftUI

/// Pill height from the Figma frames (32pt padding + 17pt label + borders).
private let onboardingPillHeight: CGFloat = 83

/// A flat grey capsule button — the one button shape of the onboarding.
/// `highlighted` inverts it (white on black / black on white) for the
/// single main action of the last step.
struct OnboardingPillButton: View {
    let title: String
    var highlighted = false
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(highlighted ? OnboardingFont.highlightedPill : OnboardingFont.compact)
                .foregroundColor(highlighted ? .onbHighlightText : .onbText)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: onboardingPillHeight)
                .background(highlighted ? Color.onbHighlight : Color.onbPill, in: Capsule())
                .overlay(Capsule().strokeBorder(highlighted ? Color.onbHighlight : Color.onbPillBorder, lineWidth: 1))
                .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(TapScaleButtonStyle())
        .disabled(!isEnabled)
    }
}

/// The round-ish "‹" button beside the main action.
struct OnboardingBackButton: View {
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.onbText.opacity(0.5))
                .frame(width: 107, height: onboardingPillHeight)
                .background(Color.onbPill, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.onbPillBorder, lineWidth: 1))
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(TapScaleButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel("Back")
    }
}

/// "‹" + main action, side by side — the bottom row of every intro step.
struct OnboardingActionRow: View {
    var title = "Continue"
    var highlighted = false
    var canGoBack = true
    var onBack: () -> Void
    var onContinue: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            OnboardingBackButton(isEnabled: canGoBack, action: onBack)
            OnboardingPillButton(title: title, highlighted: highlighted, action: onContinue)
        }
        .padding(.horizontal, 56)
    }
}

/// A text field dressed as a pill — the email and code steps.
struct OnboardingFieldPill<Trailing: View>: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var submitLabel: SubmitLabel = .done
    var focusOnAppear = false
    var onSubmit: () -> Void = {}
    @ViewBuilder var trailing: () -> Trailing

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundColor(.onbText.opacity(0.6))
            )
            .font(OnboardingFont.compact)
            .foregroundColor(.onbText)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .focused($isFocused)
            .onSubmit(onSubmit)

            trailing()
        }
        .padding(.horizontal, 48)
        .frame(height: onboardingPillHeight)
        .background(Color.onbPill, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.onbPillBorder, lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
        .onAppear { if focusOnAppear { isFocused = true } }
        .padding(.horizontal, 46)
    }
}

extension OnboardingFieldPill where Trailing == EmptyView {
    init(
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .done,
        focusOnAppear: Bool = false,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.init(
            placeholder: placeholder,
            text: text,
            keyboard: keyboard,
            contentType: contentType,
            submitLabel: submitLabel,
            focusOnAppear: focusOnAppear,
            onSubmit: onSubmit,
            trailing: { EmptyView() }
        )
    }
}

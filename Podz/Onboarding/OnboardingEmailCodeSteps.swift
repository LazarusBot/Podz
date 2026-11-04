import SwiftUI

/// Step 2 — "Only this needed". One field, one email; the code step that
/// follows does the rest. Works for new and returning users alike.
struct OnboardingEmailStep: View {
    @StateObject private var auth = AuthManager.shared
    @Binding var email: String
    var onCodeSent: () -> Void
    @State private var legal: LegalDocument?

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isValid: Bool {
        let parts = trimmedEmail.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !trimmedEmail.contains(" ")
    }

    var body: some View {
        OnboardingHeroScreen(
            photo: "ObTerrace",
            photoStyle: .card,
            title: "Only this needed",
            subtitle: "No stress, no multiple fields, just your mail."
        ) {
            VStack(spacing: 14) {
                OnboardingFieldPill(
                    placeholder: "Tap your email",
                    text: $email,
                    keyboard: .emailAddress,
                    contentType: .emailAddress,
                    submitLabel: .continue,
                    focusOnAppear: true,
                    onSubmit: submit,
                    trailing: { if auth.isLoading { ProgressView() } }
                )

                // Reserved height so an error appearing doesn't push the
                // pill around.
                T(auth.lastError.map(OnboardingErrorText.short) ?? " ")
                    .font(OnboardingFont.caption)
                    .foregroundColor(.appBadgeRed)
                    .lineLimit(1)
                    .padding(.horizontal, 32)

                // Continuing is accepting: the two documents are one tap away.
                Text(.init(tr("By continuing you accept the [Terms](podz-legal://terms) and the [Privacy Policy](podz-legal://privacy).")))
                    .font(OnboardingFont.caption)
                    .foregroundColor(.onbSubtitle)
                    .tint(.onbText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .environment(\.openURL, OpenURLAction { url in
                        legal = url.host == "privacy" ? .privacy : .terms
                        return .handled
                    })
            }
        }
        .sheet(item: $legal) { document in
            LegalDocumentView(document: document, respectsSafeArea: true) { legal = nil }
        }
        .onAppear { auth.lastError = nil }
    }

    private func submit() {
        guard isValid, !auth.isLoading else { return }
        Task {
            if await auth.sendEmailCode(to: trimmedEmail) {
                onCodeSent()
            }
        }
    }
}

/// Step 3 — "Check your inbox". Verifies on the sixth digit; no button.
struct OnboardingCodeStep: View {
    @StateObject private var auth = AuthManager.shared
    let email: String
    var onChangeEmail: () -> Void
    /// Only called for a brand-new account — a returning user's session
    /// landing already swaps the root view to the app.
    var onNewAccount: () -> Void

    @State private var code = ""
    @State private var resendNote: String?

    private static let codeLength = 6

    var body: some View {
        OnboardingHeroScreen(
            photo: "ObChalet",
            photoStyle: .card,
            title: "Check your inbox",
            subtitle: "We sent you a 6-digit code. Enter it to get in."
        ) {
            VStack(spacing: 14) {
                OnboardingFieldPill(
                    placeholder: "Enter your code",
                    text: $code,
                    keyboard: .numberPad,
                    contentType: .oneTimeCode,
                    focusOnAppear: true,
                    // Labelled, not a trailing closure: that would bind to
                    // the `onSubmit` parameter before it.
                    trailing: { if auth.isLoading { ProgressView() } }
                )

                footer
            }
        }
        .onAppear { auth.lastError = nil }
        .onChange(of: code) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(Self.codeLength))
            if digits != newValue { code = digits }
            if digits.count == Self.codeLength { verify() }
        }
    }

    /// An error, a "code sent" note, or the two quiet links — one line,
    /// fixed height.
    @ViewBuilder
    private var footer: some View {
        Group {
            if let error = auth.lastError {
                T(OnboardingErrorText.short(error)).foregroundColor(.appBadgeRed)
            } else if let resendNote {
                T(resendNote).foregroundColor(.onbSubtitle)
            } else {
                HStack(spacing: 8) {
                    Button(tr("Resend code"), action: resend)
                    T("·")
                    Button(tr("Change email"), action: onChangeEmail)
                }
                .foregroundColor(.onbSubtitle)
            }
        }
        .font(OnboardingFont.caption)
        .lineLimit(1)
        .frame(height: 16)
        .padding(.horizontal, 32)
    }

    private func verify() {
        guard !auth.isLoading else { return }
        Task {
            switch await auth.verifyEmailCode(email: email, code: code) {
            case .newAccount: onNewAccount()
            case .existingAccount: break
            case .failed: code = ""
            }
        }
    }

    private func resend() {
        Task {
            guard await auth.sendEmailCode(to: email) else { return }
            resendNote = "New code sent."
            try? await Task.sleep(for: .seconds(3))
            resendNote = nil
        }
    }
}

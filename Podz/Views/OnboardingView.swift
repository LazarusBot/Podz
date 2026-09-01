import SwiftUI
import AuthenticationServices
import Combine
import UIKit

/// OnboardingView.swift — acts as the project's welcome/onboarding entry.
/// This file integrates a small auth flow (Welcome → Login / Register)
/// wired to Supabase Auth via `AuthManager` (see Auth/AuthManager.swift).
/// Navigation to HomeView is driven by `AuthManager.isAuthenticated`,
/// which stays in sync automatically with the real Supabase session.
/// A one-time 4-step onboarding (see PostRegisterOnboardingView.swift)
/// is inserted between a successful register and MainTabView, gated by
/// `AuthManager.justRegistered` — logging in skips straight to the app.
struct OnboardingView: View {
    @StateObject private var auth = AuthManager.shared

    var body: some View {
        if auth.isInitializing {
            LaunchLoadingView()
        } else if auth.isAuthenticated {
            if auth.justRegistered {
                PostRegisterOnboardingView(onFinished: auth.finishPostRegisterOnboarding)
            } else {
                MainTabView()
            }
        } else {
            AuthFlow()
        }
    }
}

/// Shown for the brief moment between app launch and the auth state
/// resolving — replaces what was previously a blank white flash while
/// `session` sat at its default `nil` before authStateChanges emitted
/// anything. Echoes HomeView's own layout (header, search pill, a row of
/// pod cards) as gray placeholder shapes, so launch reads as "your feed is
/// arriving" rather than a generic spinner.
private struct LaunchLoadingView: View {
    /// Same sizing as `PodSection.cardSize` — two cards on screen plus a
    /// sliver of a third peeking at the trailing edge.
    private var cardSize: CGFloat {
        (UIScreen.main.bounds.width - 24 - 2 * 12 - 24) / 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonShape(cornerRadius: 4).frame(width: 90, height: 12)
                    SkeletonShape(cornerRadius: 5).frame(width: 130, height: 20)
                }
                Spacer()
                SkeletonShape(cornerRadius: 21).frame(width: 42, height: 42)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            SkeletonShape(cornerRadius: 26)
                .frame(height: 52)
                .padding(.horizontal, 24)

            SkeletonShape(cornerRadius: 5)
                .frame(width: 170, height: 18)
                .padding(.leading, 24)
                .padding(.top, 28)
                .padding(.bottom, 12)

            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonShape(cornerRadius: 18).frame(width: cardSize, height: cardSize)
                        SkeletonShape(cornerRadius: 4).frame(width: cardSize * 0.55, height: 14)
                            .padding(.leading, 5)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
    }
}

// MARK: - AuthFlow
struct AuthFlow: View {
    enum Route { case welcome, login, register }

    @State private var route: Route = .welcome

    var body: some View {
        ZStack {
            switch route {
            case .welcome:
                WelcomeView(
                    onLogin: { route = .login },
                    onRegister: { route = .register }
                )
                .transition(.opacity)

            case .login:
                LoginView(
                    onBack: { route = .welcome },
                    onGoToRegister: { route = .register }
                )
                // Plain crossfade, same as Welcome's own transition —
                // `.move` translates the whole rendered layer (background
                // photo included) as one unit, and that translation's edge
                // anti-aliases against whatever sits behind it in the
                // ZStack, showing up as a hairline seam the whole time it's
                // moving (any backdrop color still shows through it, just
                // recolored). A pure opacity dissolve never moves that
                // edge, so there's nothing to seam.
                .transition(.opacity)

            case .register:
                RegisterView(
                    onBack: { route = .welcome },
                    onGoToLogin: { route = .login }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: route)
    }
}

// MARK: - WelcomeView (the project's "Welcome" / onboarding start)
struct WelcomeView: View {
    var onLogin: () -> Void
    var onRegister: () -> Void

    @State private var legalDocument: LegalDocument?

    var body: some View {
        AuthBackground(showBackButton: false, showLogo: false) {
            VStack {
                Group {
                    if UIImage(named: "podz") != nil {
                        Image("podz").resizable().scaledToFit().frame(height: 60)
                    } else {
                        Text("Podz")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 140)

                Spacer(minLength: 250)
                
                VStack(spacing: 32) {
                    Button(action: onRegister) {
                        HStack(spacing: 10) {
                            Text("Get started")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    // Border distinct from the fill, not matching it —
                    // `appAccentBlack` is near-solid black, which all but
                    // disappears against `AuthBackground`'s photo gradient
                    // (it fades to black right where this button sits).
                    // Same translucent-white-border-on-dark-photo trick as
                    // the back chevron button elsewhere in `AuthBackground`.
                    .pillStyle(fill: .appAccentBlack, border: .white.opacity(0.3))

                    Button(action: onLogin) {
                        HStack(spacing: 10) {
                            Text("Login")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .pillStyle(fill: .white, border: .appBorder)
                }
                .padding(.horizontal, 32)

                legalCaption
                    .padding(.top, 16)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document)
        }
    }

    /// Plain-text sentence with two inline tap targets — matches
    /// `AuthFooterLink`'s "underline the actionable part" language rather
    /// than introducing a new link style just for this one line.
    private var legalCaption: some View {
        HStack(spacing: 4) {
            Text("By continuing, you agree to our")
                .foregroundColor(.appWhite88)
            Text("Terms")
                .foregroundColor(.white)
                .underline()
                .onTapGesture { legalDocument = .terms }
            Text("and")
                .foregroundColor(.appWhite88)
            Text("Privacy Policy")
                .foregroundColor(.white)
                .underline()
                .onTapGesture { legalDocument = .privacy }
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

/// Which legal doc `LegalDocumentView` is showing — `Identifiable` so it
/// can drive a `.sheet(item:)` directly instead of a separate Bool flag
/// per document.
enum LegalDocument: String, Identifiable {
    case terms, privacy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: "Terms of Service"
        case .privacy: "Privacy Policy"
        }
    }

    /// Placeholder copy — enough to link to from the Welcome screen now
    /// rather than shipping a dead link, but not a substitute for review
    /// by an actual lawyer before this app is public.
    var body: String {
        switch self {
        case .terms: """
            Last updated: August 2026

            Welcome to Podz. By creating an account or using the app, you agree to these Terms.

            ACCOUNTS
            You're responsible for the accuracy of the information you provide and for keeping your login credentials secure. You must be old enough to legally use social apps in your country.

            YOUR CONTENT
            You keep ownership of the photos, posts, and comments you share on Podz. By posting, you grant Podz a license to store and display that content within the app so other users (and, depending on your settings, their friends) can see it.

            ACCEPTABLE USE
            Don't use Podz to post illegal content, harass other users, or attempt to disrupt the service.

            TERMINATION
            We may suspend or terminate accounts that violate these Terms.

            CHANGES
            We may update these Terms as the app evolves. Continued use after an update means you accept the revised Terms.

            CONTACT
            Questions about these Terms can be sent to the app's support contact.
            """
        case .privacy: """
            Last updated: August 2026

            This Privacy Policy explains what Podz collects and how it's used.

            INFORMATION WE COLLECT
            Account info you provide (name, username, email), content you create (photos, posts, likes, comments), and basic usage data needed to run the app.

            HOW WE USE IT
            To operate your feed, show your posts to friends, power search and notifications, and keep the app secure.

            SIGN IN WITH APPLE
            If you sign in with Apple, we only receive what Apple shares per your chosen settings (name and email, or a private relay address).

            SHARING
            We don't sell your data. Content is stored with our backend infrastructure provider (Supabase) solely to run the app.

            YOUR CHOICES
            You can edit your profile, delete posts, or delete your account at any time from Settings.

            CONTACT
            Questions about this policy can be sent to the app's support contact.
            """
        }
    }
}

/// Full-screen legal doc reader — same close-icon + bold title header as
/// `PostsActivityView`, just with a long scrollable body instead of a list.
struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextMuted)
                        .frame(width: 31, height: 31)
                        .background(Circle().fill(Color(white: 0.93)))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text(document.title)
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                Text(document.body)
                    .font(AppFont.mediumLabel(14))
                    .foregroundColor(.black.opacity(0.75))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .background(Color.appHomeBackground)
    }
}

// MARK: - LoginView
struct LoginView: View {
    var userFirstName: String = ""
    var onBack: () -> Void
    var onGoToRegister: () -> Void
    
    @StateObject private var auth = AuthManager.shared
    /// Email or username — whichever the user types. `AuthManager.signIn`
    /// resolves a username to its email server-side before ever calling
    /// Supabase Auth, which only ever knows email/password.
    @State private var identifier = ""
    @State private var password = ""
    @State private var nonce = ""
    @State private var showResetConfirmation = false
    @StateObject private var appleCoordinator = AppleSignInWrapper()
    @FocusState private var focusedField: AuthField?
    @State private var identifierError: String?

    private var canSubmit: Bool { !identifier.isEmpty && !password.isEmpty }

    private func submit() {
        focusedField = nil
        Task { await auth.signIn(identifier: identifier, password: password) }
    }

    var body: some View {
        AuthBackground(onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                Text(userFirstName.isEmpty ? "Welcome back!" : "Welcome back,\n\(userFirstName)!")
                    .font(AppFont.pillLabelBold(40))
                    .tracking(-1)
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .padding(.top, 51)

                Color.clear.frame(height: 24)

                VStack(spacing: 12) {
                    AuthTextField(
                        placeholder: "Email or username", text: $identifier,
                        // .default, not .emailAddress — this field takes
                        // either, and forcing the email keyboard layout
                        // for a username entry isn't right. .username
                        // (not .emailAddress) is also what lets iOS offer
                        // the correct saved-credential autofill either way.
                        keyboardType: .default, textContentType: .username,
                        field: .email, focusedField: $focusedField,
                        onSubmit: { focusedField = .password },
                        // Only flags something that looks like a *broken*
                        // email attempt (has an "@" but isn't valid) — a
                        // plain username never has "@", so it's never
                        // held to email formatting at all.
                        validate: { $0.contains("@") && !isValidEmail($0) ? "Enter a valid email address." : nil },
                        onValidationChange: { identifierError = $0 }
                    )
                    AuthTextField(
                        placeholder: "Enter your password", text: $password, isSecure: true,
                        textContentType: .password, submitLabel: .go,
                        field: .password, focusedField: $focusedField,
                        onSubmit: submit
                    )

                    HStack {
                        Spacer()
                        Text("Forgot password ?")
                            .font(.system(size: 12))
                            .foregroundColor(.appWhite88)
                            .underline()
                            .onTapGesture(perform: handleForgotPassword)
                    }
                }

                if let identifierError {
                    AuthErrorBanner(message: identifierError)
                        .padding(.top, 12)
                }

                if let error = auth.lastError {
                    AuthErrorBanner(message: error)
                        .padding(.top, 12)
                }

                Spacer(minLength: 24)

                Button(action: submit) {
                    HStack(spacing: 10) {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Login")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .disabled(auth.isLoading || !canSubmit)
                // Fading the whole button (fill included) barely reads as
                // "disabled" here — `appAccentBlack` is already near-black,
                // so halving its opacity mostly just dims the white text
                // while the fill itself stays close to invisible against
                // this screen's own dark photo backdrop. A distinct gray
                // fill instead of a faded black one is visible either way,
                // and now that the fill itself is visible, fading it too
                // reinforces "disabled" rather than erasing the button.
                .pillStyle(fill: canSubmit ? .appAccentBlack : .appTextMuted, border: canSubmit ? .appBorder : .appTextMuted)
                .opacity(canSubmit ? 1 : 0.6)

                DividerOr()
                    .padding(.vertical, 24)

                SignInWithAppleButtonView(style: .login) {
                    nonce = AppleNonce.random()
                    appleCoordinator.start(hashedNonce: AppleNonce.sha256(nonce))
                }
                .frame(height: 50)

                Color.clear.frame(height: 32)
                
                AuthFooterLink(
                    question: "Don't have an account ?",
                    actionLabel: "Register now",
                    onTap: onGoToRegister
                )
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 32)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
            .animation(.easeOut(duration: AppMotion.standard), value: auth.lastError)
            .animation(.easeOut(duration: AppMotion.standard), value: identifierError)
        }
        .onAppear {
            appleCoordinator.onSuccess = { credential in
                guard let tokenData = credential.identityToken,
                      let idToken = String(data: tokenData, encoding: .utf8) else { return }
                Task { await auth.signInWithApple(idToken: idToken, rawNonce: nonce) }
            }
        }
        .alert("Check your email", isPresented: $showResetConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We sent a password reset link to \(identifier).")
        }
    }

    /// Needs an actual email — unlike sign-in, there's no username lookup
    /// for the reset link itself (Supabase's own reset-password call only
    /// takes an email), so a username typed into this same field can't be
    /// used here.
    private func handleForgotPassword() {
        guard !identifier.isEmpty else {
            auth.lastError = "Enter your email first."
            return
        }
        guard isValidEmail(identifier) else {
            auth.lastError = "Enter your email (not your username) to reset your password."
            return
        }
        Task {
            if await auth.resetPassword(email: identifier) {
                showResetConfirmation = true
            }
        }
    }
}

// MARK: - RegisterView
struct RegisterView: View {
    var onBack: () -> Void
    var onGoToLogin: () -> Void
    
    @StateObject private var auth = AuthManager.shared
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var nonce = ""
    @StateObject private var appleCoordinator = AppleSignInWrapper()
    @FocusState private var focusedField: AuthField?
    @State private var emailError: String?
    @State private var passwordError: String?

    private var canSubmit: Bool {
        !name.isEmpty && !username.isEmpty && !email.isEmpty && !password.isEmpty
    }

    private func submit() {
        focusedField = nil
        Task {
            await auth.signUp(name: name, username: username, email: email, password: password)
        }
    }

    var body: some View {
        AuthBackground(onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Register to discover\nthe best podz.")
                    .font(AppFont.pillLabelBold(40))
                    .tracking(-1)
                    .foregroundColor(.white)
                    .lineSpacing(0)
                    .padding(.top, 51)
                
                Spacer(minLength: 24)
                
                VStack(spacing: 12) {
                    AuthTextField(
                        placeholder: "Enter your name", text: $name,
                        textContentType: .name,
                        field: .name, focusedField: $focusedField,
                        onSubmit: { focusedField = .username }
                    )
                    AuthTextField(
                        placeholder: "Enter your username", text: $username,
                        textContentType: .username,
                        field: .username, focusedField: $focusedField,
                        onSubmit: { focusedField = .email }
                    )
                    AuthTextField(
                        placeholder: "Enter your email", text: $email,
                        keyboardType: .emailAddress, textContentType: .emailAddress,
                        field: .email, focusedField: $focusedField,
                        onSubmit: { focusedField = .password },
                        validate: { isValidEmail($0) ? nil : "Enter a valid email address." },
                        onValidationChange: { emailError = $0 }
                    )
                    AuthTextField(
                        placeholder: "Enter your password", text: $password, isSecure: true,
                        textContentType: .newPassword, submitLabel: .done,
                        field: .password, focusedField: $focusedField,
                        onSubmit: submit,
                        validate: { $0.count >= minPasswordLength ? nil : "At least \(minPasswordLength) characters." },
                        onValidationChange: { passwordError = $0 }
                    )
                }

                if let emailError {
                    AuthErrorBanner(message: emailError)
                        .padding(.top, 12)
                }

                if let passwordError {
                    AuthErrorBanner(message: passwordError)
                        .padding(.top, 12)
                }

                if let error = auth.lastError {
                    AuthErrorBanner(message: error)
                        .padding(.top, 12)
                }

                Spacer(minLength: 24)
                
                Button(action: submit) {
                    HStack(spacing: 10) {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Register")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .disabled(auth.isLoading || !canSubmit)
                .pillStyle(fill: canSubmit ? .appAccentBlack : .appTextMuted, border: canSubmit ? .appBorder : .appTextMuted)
                .opacity(canSubmit ? 1 : 0.6)

                DividerOr()
                    .padding(.vertical, 24)

                SignInWithAppleButtonView(style: .register) {
                    nonce = AppleNonce.random()
                    appleCoordinator.start(hashedNonce: AppleNonce.sha256(nonce))
                }
                .frame(height: 50)
                
                Spacer(minLength: 32)
                
                AuthFooterLink(
                    question: "Already have an account ?",
                    actionLabel: "Login now",
                    onTap: onGoToLogin
                )
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 32)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
            .animation(.easeOut(duration: AppMotion.standard), value: auth.lastError)
            .animation(.easeOut(duration: AppMotion.standard), value: emailError)
            .animation(.easeOut(duration: AppMotion.standard), value: passwordError)
        }
        .onAppear {
            appleCoordinator.onSuccess = { credential in
                guard let tokenData = credential.identityToken,
                      let idToken = String(data: tokenData, encoding: .utf8) else { return }
                Task { await auth.signInWithApple(idToken: idToken, rawNonce: nonce) }
            }
        }
    }
}

// MARK: - Shared Components (AuthBackground, fields, buttons)
struct AuthBackground<Content: View>: View {
    var showBackButton: Bool = true
    var showLogo: Bool = true
    /// The dark bottom gradient used by Welcome/Login/Register — some
    /// onboarding steps have no gradient at all per their Figma frame.
    var showGradient: Bool = true
    /// Asset name for the full-bleed background photo.
    var imageName: String = "bg"
    var onBack: () -> Void = {}
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if showBackButton {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                    }
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 24)
            
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Keeps Login/Register fixed in place instead of SwiftUI's
        // default behavior of sliding the whole screen up to keep the
        // focused field clear of the keyboard — the fields already sit
        // well above where the keyboard covers, so that shift was just
        // unwanted movement, not something protecting visibility here.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Full-bleed background: image sized via GeometryReader to the
        // true full-screen bounds *before* scaledToFill runs (avoids the
        // safe-area seam), single ignoresSafeArea() applied once here.
        .background(
            GeometryReader { proxy in
                ZStack {
                    if UIImage(named: imageName) != nil {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        LinearGradient.appAuthImageFallback
                    }
                    
                    if showGradient {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.30),
                                .init(color: .black.opacity(0.75), location: 0.60),
                                .init(color: .black, location: 0.90)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                }
            }
                .ignoresSafeArea()
        )
    }
}

/// Identifies which field currently has keyboard focus — shared across
/// LoginView/RegisterView (each just uses the subset of cases it needs)
/// so `AuthTextField` instances can both show a focus ring and chain
/// "next" to the following field via the keyboard's return key.
enum AuthField: Hashable {
    case name, username, email, password
}

/// Lightweight, deliberately permissive check — just enough to catch an
/// obviously-incomplete address (no "@", nothing after the last ".")
/// before it round-trips to the server, not a full RFC 5322 validator.
private func isValidEmail(_ text: String) -> Bool {
    text.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
}

/// Supabase's own default minimum — client-side check can't be stricter
/// than whatever this project's Auth settings actually enforce, but it
/// can't be looser than Supabase's own floor either, so this is always
/// a safe minimum to warn on before submitting.
private let minPasswordLength = 6

struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    /// Feeds iOS autofill/Password AutoFill — `.password` on Login (so
    /// it offers an *existing* saved credential) vs `.newPassword` on
    /// Register (so it offers the strong-password suggestion instead).
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next
    let field: AuthField
    var focusedField: FocusState<AuthField?>.Binding
    /// Return key handler — the parent decides whether that means
    /// advancing to the next field or firing the actual submit action.
    var onSubmit: () -> Void = {}
    /// Returns a short hint to show below the field when `text` looks
    /// invalid, or nil when it's fine — checked live but only *displayed*
    /// once the user has actually left the field (see `validationMessage`),
    /// so it doesn't nag mid-keystroke for something like an email that's
    /// only half-typed.
    var validate: ((String) -> String?)? = nil
    /// Reports `validationMessage` up whenever it changes, instead of
    /// this view rendering the hint itself — the parent collects every
    /// field's current message and shows them together below the whole
    /// field stack, rather than one popping up between two fields and
    /// shoving the rest of the form down.
    var onValidationChange: (String?) -> Void = { _ in }
    @State private var isRevealed = false

    private var isFocused: Bool { focusedField.wrappedValue == field }

    private var validationMessage: String? {
        guard !isFocused, !text.isEmpty else { return nil }
        return validate?(text)
    }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isSecure && !isRevealed {
                    SecureField("", text: $text, prompt: placeholderText)
                } else {
                    TextField("", text: $text, prompt: placeholderText)
                        .keyboardType(keyboardType)
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(textContentType)
            .font(AppFont.pillLabelSemiBold(20))
            .foregroundColor(.black)
            .focused(focusedField, equals: field)
            .submitLabel(submitLabel)
            .onSubmit {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSubmit()
            }
            .onChange(of: text) { _, _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundColor(.appPlaceholder)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.appFieldBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(isFocused ? Color.appAccentBlack : Color.appBorder, lineWidth: isFocused ? 1.5 : 0.5)
                )
                .shadow(color: Color.black.opacity(isFocused ? 0.18 : 0.12), radius: isFocused ? 6 : 4, x: 1, y: 3)
        )
        .animation(.easeOut(duration: AppMotion.quick), value: isFocused)
        .onChange(of: validationMessage) { _, new in
            onValidationChange(new)
        }
    }

    private var placeholderText: Text {
        Text(placeholder).foregroundColor(.appPlaceholder)
    }
}

/// Auth error display — a red-tinted card instead of plain floating red
/// text, so it reads as a distinct, designed piece of UI against the
/// dark photo background rather than blending into it. Shared between
/// Login and Register (Register previously had no icon at all, unlike
/// Login — now both match).
struct AuthErrorBanner: View {
    let message: String

    /// Supabase Auth's own error strings are stable, documented text
    /// (not something invented here) but read as backend jargon —
    /// swapped for plain language on the ones worth the trouble.
    /// Anything unrecognized falls through unchanged rather than being
    /// hidden, so a genuinely new error is never suppressed.
    private var friendlyMessage: String {
        let lower = message.lowercased()
        if lower.contains("user already registered") {
            return "An account with this email already exists."
        } else if lower.contains("invalid login credentials") {
            return "Incorrect email or password."
        } else if lower.contains("password should be at least") {
            return "Password must be at least \(minPasswordLength) characters."
        } else if lower.contains("unable to validate email address") {
            return "That doesn't look like a valid email address."
        } else if lower.contains("email not confirmed") {
            return "Please confirm your email before signing in."
        }
        return message
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13))
            Text(friendlyMessage)
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct DividerOr: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
            Text("or")
                .font(AppFont.pillLabelSemiBold(16))
                .foregroundColor(.white)
            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
        }
    }
}

struct AuthFooterLink: View {
    let question: String
    let actionLabel: String
    var onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Text(question + " ")
                .foregroundColor(.appWhite88)
            Text(actionLabel)
                .foregroundColor(.appLinkGreen)
                .underline()
        }
        .font(.system(size: 14))
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Sign in with Apple wrapper & coordinator
struct SignInWithAppleButtonView: UIViewRepresentable {
    enum Style { case login, register }
    var style: Style
    var action: () -> Void
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let type: ASAuthorizationAppleIDButton.ButtonType = (style == .login) ? .signIn : .signUp
        let button = ASAuthorizationAppleIDButton(type: type, style: .white)
        button.cornerRadius = 999
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    
    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    var onSuccess: (ASAuthorizationAppleIDCredential) -> Void = { _ in }
    var onFailure: (Error) -> Void = { _ in }
    
    /// `hashedNonce` = SHA256 of the raw nonce you generated with
    /// `AppleNonce.random()`. Pass the SAME raw nonce (unhashed) to
    /// `AuthManager.signInWithApple` once you get the identity token back.
    func start(hashedNonce: String) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            onSuccess(credential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onFailure(error)
    }
}

final class AppleSignInWrapper: ObservableObject {
    private let coordinator = AppleSignInCoordinator()
    var onSuccess: (ASAuthorizationAppleIDCredential) -> Void = { _ in }
    
    init() {
        coordinator.onSuccess = { [weak self] credential in
            self?.onSuccess(credential)
        }
    }
    
    func start(hashedNonce: String) { coordinator.start(hashedNonce: hashedNonce) }
}

// Previews
#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
#endif

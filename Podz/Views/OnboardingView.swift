import SwiftUI
import AuthenticationServices
import Combine
import UIKit

/// OnboardingView.swift — acts as the project's welcome/onboarding entry.
/// This file integrates a small auth flow (Welcome → Login / Register)
/// wired to Supabase Auth via `AuthManager` (see Auth/AuthManager.swift).
/// Navigation to HomeView is driven by `AuthManager.isAuthenticated`,
/// which stays in sync automatically with the real Supabase session.
struct OnboardingView: View {
    @StateObject private var auth = AuthManager.shared
    
    var body: some View {
        if auth.isInitializing {
            LaunchLoadingView()
        } else if auth.isAuthenticated {
            MainTabView()
        } else {
            AuthFlow(onAuthenticated: {})
        }
    }
}

/// Shown for the brief moment between app launch and the auth state
/// resolving — replaces what was previously a blank white flash while
/// `session` sat at its default `nil` before authStateChanges emitted
/// anything.
private struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            Color.appHomeBackground.ignoresSafeArea()
            ProgressView()
                .tint(.appAccentBlack)
        }
    }
}

// MARK: - AuthFlow
struct AuthFlow: View {
    enum Route { case welcome, login, register }
    
    @State private var route: Route = .welcome
    
    /// Called only for "Continue as a guest" — real login/register success
    /// is picked up automatically by OnboardingView via auth.isAuthenticated,
    /// no need to call this from LoginView/RegisterView anymore.
    var onAuthenticated: () -> Void = {}
    
    var body: some View {
        ZStack {
            switch route {
            case .welcome:
                WelcomeView(
                    onLogin: { route = .login },
                    onRegister: { route = .register },
                    onGuest: onAuthenticated
                )
                .transition(.opacity)
                
            case .login:
                LoginView(
                    onBack: { route = .welcome },
                    onGoToRegister: { route = .register }
                )
                .transition(.move(edge: .trailing))
                
            case .register:
                RegisterView(
                    onBack: { route = .welcome },
                    onGoToLogin: { route = .login }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: route)
    }
}

// MARK: - WelcomeView (the project's "Welcome" / onboarding start)
struct WelcomeView: View {
    var onLogin: () -> Void
    var onRegister: () -> Void
    var onGuest: () -> Void
    
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
                .padding(.top, 200)
                
                Spacer(minLength: 250)
                
                VStack(spacing: 32) {
                    Button(action: onLogin) {
                        HStack {
                            Text("Login")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .pillStyle(fill: .appAccentBlack, border: .appAccentBlack)
                    
                    Button(action: onRegister) {
                        HStack {
                            Text("Register")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .pillStyle(fill: .white, border: .appBorder)
                    
                    Text("Continue as a guest")
                        .font(.system(size: 14))
                        .foregroundColor(.appLinkGreen)
                        .underline()
                        .onTapGesture(perform: onGuest)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
                
                Spacer()
            }
        }
    }
}

// MARK: - LoginView
struct LoginView: View {
    var userFirstName: String = ""
    var onBack: () -> Void
    var onGoToRegister: () -> Void
    
    @StateObject private var auth = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var nonce = ""
    @StateObject private var appleCoordinator = AppleSignInWrapper()
    
    var body: some View {
        AuthBackground(onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                Text(userFirstName.isEmpty ? "Welcome back!" : "Welcome back,\n\(userFirstName)!")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .padding(.top, 51)
                
                Spacer(minLength: 24)
                
                VStack(spacing: 16) {
                    AuthTextField(placeholder: "Enter your email", text: $email, keyboardType: .emailAddress)
                    AuthTextField(placeholder: "Enter your password", text: $password, isSecure: true)
                    
                    HStack {
                        Spacer()
                        Text("Forgot password ?")
                            .font(.system(size: 12))
                            .foregroundColor(.appWhite88)
                    }
                }
                
                if let error = auth.lastError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(.top, 12)
                }
                
                Spacer(minLength: 32)
                
                VStack(spacing: 12) {
                    Button {
                        Task { await auth.signIn(email: email, password: password) }
                    } label: {
                        HStack {
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .disabled(auth.isLoading)
                    .pillStyle(fill: .appAccentBlack, border: .appAccentBlack)
                    
                    SignInWithAppleButtonView(style: .login) {
                        nonce = AppleNonce.random()
                        appleCoordinator.start(hashedNonce: AppleNonce.sha256(nonce))
                    }
                    .frame(height: 44)
                }
                
                Spacer(minLength: 32)
                
                AuthFooterLink(
                    question: "Don't have an account ?",
                    actionLabel: "Register now",
                    onTap: onGoToRegister
                )
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 32)
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
    
    var body: some View {
        AuthBackground(onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Register to discover\nthe best podz.")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .padding(.top, 51)
                
                Spacer(minLength: 24)
                
                VStack(spacing: 16) {
                    AuthTextField(placeholder: "Enter your name", text: $name)
                    AuthTextField(placeholder: "Enter your username", text: $username)
                    AuthTextField(placeholder: "Enter your email", text: $email, keyboardType: .emailAddress)
                    AuthTextField(placeholder: "Enter your password", text: $password, isSecure: true)
                }
                
                if let error = auth.lastError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(.top, 12)
                }
                
                Spacer(minLength: 24)
                
                Button {
                    Task {
                        await auth.signUp(name: name, username: username, email: email, password: password)
                    }
                } label: {
                    HStack {
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .disabled(auth.isLoading)
                .pillStyle(fill: .appAccentBlack, border: .appAccentBlack)
                
                DividerOr()
                    .padding(.vertical, 24)
                
                SignInWithAppleButtonView(style: .register) {
                    nonce = AppleNonce.random()
                    appleCoordinator.start(hashedNonce: AppleNonce.sha256(nonce))
                }
                .frame(height: 44)
                
                Spacer(minLength: 32)
                
                AuthFooterLink(
                    question: "Already have an account ?",
                    actionLabel: "Login now",
                    onTap: onGoToLogin
                )
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 32)
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
    var onBack: () -> Void = {}
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if showBackButton {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 31, height: 31)
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
        // Full-bleed background: image sized via GeometryReader to the
        // true full-screen bounds *before* scaledToFill runs (avoids the
        // safe-area seam), single ignoresSafeArea() applied once here.
        .background(
            GeometryReader { proxy in
                ZStack {
                    if UIImage(named: "bg") != nil {
                        Image("bg")
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.1, green: 0.3, blue: 0.4), .black],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                    
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
                .ignoresSafeArea()
        )
    }
}

struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: placeholderText)
            } else {
                TextField("", text: $text, prompt: placeholderText)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .font(AppFont.pillLabel(16))
        .foregroundColor(.black)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.appFieldBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(Color.appBorder, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 1, y: 3)
        )
    }
    
    private var placeholderText: Text {
        Text(placeholder).foregroundColor(.appPlaceholder)
    }
}

struct DividerOr: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1)
            Text("or")
                .font(AppFont.pillLabel(16))
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

// MARK: - Small color tokens used by auth UI
extension Color {
    static let appPlaceholder = Color.black.opacity(0.25)
    static let appLinkGreen = Color(red: 0xC4/255, green: 0xFF/255, blue: 0xC9/255)
    static let appWhite88 = Color.white.opacity(0.88)
    static let appFieldBg = Color.white.opacity(0.99)
}

// Previews
#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
#endif

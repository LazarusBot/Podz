import SwiftUI
internal import Auth

/// Reached by tapping "Login and security" on ProfileView. Shows the
/// account's email and sign-in method (both read from the Supabase
/// session — real data, not placeholders) and lets you trigger a
/// password-reset email via `AuthManager.resetPassword`, which already
/// existed for the logged-out "forgot password" flow.
struct LoginSecurityView: View {
    var onBack: () -> Void

    @StateObject private var auth = AuthManager.shared
    @State private var showResetConfirmation = false

    private var email: String {
        auth.session?.user.email ?? "—"
    }

    /// First linked identity's provider ("email", "apple", ...) — good
    /// enough to answer "how do I sign in", the only thing this screen
    /// needs it for.
    private var signInMethod: String {
        auth.session?.user.identities?.first?.provider.capitalized ?? "Email"
    }

    var body: some View {
        SectionPage(title: "Login and security", onBack: onBack) {
            InfoRow(value: email, label: "Email")
            InfoRow(value: signInMethod, label: "Sign-in method")

            if signInMethod == "Email" {
                // No chevron — this performs the send right here, it
                // doesn't navigate to another screen.
                ProfileMenuRow(icon: "envelope", title: "Send password reset email", showsChevron: false) {
                    Task {
                        guard await auth.resetPassword(email: email) else { return }
                        showResetConfirmation = true
                    }
                }
            }
        }
        .alert("Email sent", isPresented: $showResetConfirmation) {
            Button("OK") {}
        } message: {
            Text("Check \(email) for a link to reset your password.")
        }
        .errorAlert($auth.lastError)
    }
}

/// Read-only value/label pair — same rhythm as `ProfileEditRow` but without
/// the trailing pencil or tap target, since nothing here is editable.
private struct InfoRow: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AppFont.semiBoldLabel(16))
                .foregroundColor(.homeText)
            Text(label)
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

#Preview {
    LoginSecurityView(onBack: {})
}

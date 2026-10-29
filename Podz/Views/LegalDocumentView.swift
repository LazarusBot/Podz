import SwiftUI

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

    /// Placeholder copy — enough to link to from the onboarding now
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
                CloseButton(action: { dismiss() })
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

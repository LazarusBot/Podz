import SwiftUI

/// Which legal document `LegalDocumentView` shows. `Identifiable`, so it can
/// drive a `.sheet(item:)` or a page swap without a flag per document.
enum LegalDocument: String, Identifiable {
    case terms, privacy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: "Terms of Service"
        case .privacy: "Privacy Policy"
        }
    }
}

/// The Terms or the Privacy Policy, built like every page Profile opens
/// (`SectionPage`, `design.md`): a 30 semiBold title, a quiet "Last updated"
/// line, then each part under a 13 `homeSubtitle` heading with its text in 15
/// `homeBodyText`, and the back pill at the bottom. The words are in
/// `LegalText`. Opened from Profile > About Podz, and from the sign-up screen
/// (as a sheet: `respectsSafeArea`).
struct LegalDocumentView: View {
    let document: LegalDocument
    var respectsSafeArea = false
    var onBack: () -> Void

    var body: some View {
        SectionPage(title: document.title, onBack: onBack, respectsSafeArea: respectsSafeArea) {
            VStack(alignment: .leading, spacing: 0) {
                T("Last updated \(LegalText.updated)")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .padding(.horizontal, 24)

                ForEach(LegalText.sections(document), id: \.heading) { section in
                    SectionHeading(title: section.heading)
                        .padding(.top, 6)
                    Text(section.text)
                        .font(AppFont.regularLabel(15))
                        .lineSpacing(4)
                        .foregroundColor(.homeBodyText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                }

                Color.clear.frame(height: 190)
            }
        }
    }
}

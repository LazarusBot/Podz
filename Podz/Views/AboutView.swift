import SwiftUI

/// Profile > About Podz (a `SectionPage`): the version, the two legal
/// documents, the switch for anonymous usage data, and where the data comes
/// from. The legal documents open in place, like every page under Profile.
struct AboutView: View {
    var onBack: () -> Void

    @State private var legal: LegalDocument?
    /// The switch `Analytics` reads (same key, on unless turned off).
    @AppStorage("analytics.enabled") private var sharesUsage = true

    private var version: String {
        let info = Bundle.main.infoDictionary
        let number = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(number) (\(build))"
    }

    var body: some View {
        if let legal {
            LegalDocumentView(document: legal, onBack: { self.legal = nil })
        } else {
            SectionPage(title: "About Podz", onBack: onBack) {
                VStack(alignment: .leading, spacing: 0) {
                    T("Version \(version)")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        ProfileListRow(title: LegalDocument.terms.title) { legal = .terms }
                        ProfileListRow(title: LegalDocument.privacy.title) { legal = .privacy }
                        // A row that acts right here: no chevron, the state in the caption.
                        ProfileListRow(
                            title: "Share anonymous usage",
                            showsChevron: false,
                            caption: sharesUsage ? "On" : "Off"
                        ) {
                            sharesUsage.toggle()
                        }
                    }
                    .padding(.top, 28)

                    T("Hut data © OpenStreetMap contributors. Photos from Wikimedia Commons, with their credits. Not every hut is checked by Podz.")
                        .font(AppFont.regularLabel(13))
                        .lineSpacing(3)
                        .foregroundColor(.homeSubtitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    // Podz has no accessibility settings of its own, so there is
                    // no page for them: it follows the phone's.
                    T("Podz follows your iPhone's VoiceOver and Reduce Motion settings.")
                        .font(AppFont.regularLabel(13))
                        .lineSpacing(3)
                        .foregroundColor(.homeSubtitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }
            }
        }
    }
}

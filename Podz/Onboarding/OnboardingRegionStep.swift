import SwiftUI

/// Step 6 — "Where to first?". Pick one region, then "Get started" lands
/// in the app. The choice is remembered under `OnboardingRegion.storageKey`
/// for Home to pick up.
struct OnboardingRegionStep: View {
    var onBack: () -> Void
    var onFinish: (OnboardingRegion) -> Void

    @State private var selection: OnboardingRegion = .dolomites

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(OnboardingRegion.allCases) { region in
                    RegionTile(region: region, isSelected: region == selection)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: AppMotion.snappy)) { selection = region }
                        }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Spacer(minLength: 24)

            VStack(spacing: 23) {
                Text("Where to first?")
                    .font(OnboardingFont.title)
                    .foregroundColor(.onbText)

                Text("Pick a region. You can change it anytime.")
                    .font(OnboardingFont.body)
                    .foregroundColor(.onbSubtitle)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            OnboardingActionRow(
                title: "Get started",
                highlighted: true,
                onBack: onBack,
                onContinue: { onFinish(selection) }
            )
            .padding(.top, 48)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.onbBackground.ignoresSafeArea())
    }
}

enum OnboardingRegion: String, CaseIterable, Identifiable {
    case dolomites = "Dolomites"
    case montBlanc = "Mont Blanc"
    case julianAlps = "Julian Alps"
    case pyrenees = "Pyrenees"

    var id: String { rawValue }

    var photo: String {
        switch self {
        case .dolomites: "ObChalet"
        case .montBlanc: "ObHillside"
        case .julianAlps: "ObPod"
        case .pyrenees: "ObRocks"
        }
    }

    /// `UserDefaults` key for the region picked at the end of onboarding.
    static let storageKey = "preferredRegion"
}

private struct RegionTile: View {
    let region: OnboardingRegion
    let isSelected: Bool

    var body: some View {
        Color.clear
            .aspectRatio(166.0 / 216.0, contentMode: .fit)
            .overlay {
                Image(region.photo)
                    .resizable()
                    .scaledToFill()
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 90)
            }
            .overlay(alignment: .bottomLeading) {
                Text(region.rawValue)
                    .font(AppFont.semiBoldLabel(15))
                    .foregroundColor(.white)
                    .padding(.leading, 18)
                    .padding(.bottom, 16)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .background(Color.white, in: Circle())
                        .padding(14)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .opacity(isSelected ? 1 : 0.55)
            .contentShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(region.rawValue)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

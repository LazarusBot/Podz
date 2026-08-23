import SwiftUI

/// A pill-shaped chip with an optional trailing notification badge.
/// Matches the "Slovenia" chip (node 3665:1017) in the Filters screen.
struct PillChip: View {
    let title: String
    var badgeCount: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppFont.pillLabel())
                .foregroundColor(.appTextPrimary)

            if let badgeCount, badgeCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.appBadgeRed)
                        .frame(width: 15, height: 15)
                    Text("\(badgeCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .pillStyle()
    }
}

/// A filled black pill button, used for the active "Filters" state
/// and the bottom "Save" button.
struct PillButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(AppFont.pillLabel())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .pillStyle(fill: .appAccentBlack, border: .appAccentBlack)
    }
}

/// Small circular icon-only pill (the "+" button next to Filters).
struct PillIconButton: View {
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.appTextPrimary)
                .frame(width: 31, height: 31)
        }
        .pillStyle()
    }
}

struct PillChip_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            PillChip(title: "Slovenia", badgeCount: 1)
            PillButton(title: "Filters", icon: "slider.horizontal.3")
            PillIconButton(systemImage: "plus")
        }
        .padding()
        .background(Color.appBackground)
    }
}
